require 'openai'

class AiAssistantService
  def initialize(inbox, conversation)
    @inbox = inbox
    @conversation = conversation
    api_key = ENV['OPENAI_API_KEY']
    @client = OpenAI::Client.new(access_token: api_key)
  end

  def process_message
    messages = build_message_history
    system_prompt = { role: 'system', content: build_system_prompt }

    response = @client.chat(
      parameters: {
        model: 'gpt-4o',
        messages: [system_prompt] + messages,
        temperature: @inbox.ai_temperature || 0.7,
        tools: defined_tools,
        tool_choice: 'auto'
      }
    )

    text = handle_response(response, messages)
    text.present? ? split_into_messages(text) : []
  end

  private

  def build_system_prompt
    base = @inbox.ai_prompt.presence || 'Você é uma assistente virtual prestativa.'
    contact_name = @conversation.contact.name.presence || 'cliente'
    contact_phone = @conversation.contact.phone_number.presence || 'não informado'

    current_time = Time.current.in_time_zone('America/Sao_Paulo')
    dias = %w[Domingo Segunda-feira Terça-feira Quarta-feira Quinta-feira Sexta-feira Sábado]
    date_info = "Hoje é #{dias[current_time.wday]}, #{current_time.strftime('%d/%m/%Y')} às #{current_time.strftime('%H:%M')}."

    teams_list = @conversation.account.teams.pluck(:name).join(', ')
    teams_info = teams_list.present? ? "\n[EQUIPES DISPONÍVEIS PARA TRANSFERÊNCIA]: #{teams_list}. Use route_to_team com o nome exato da equipe." : ''

    catalog_categories = @conversation.account.catalog_items.active.distinct.pluck(:category).compact.join(', ')
    catalog_info = catalog_categories.present? ? "\n[CATÁLOGO]: O negócio possui produtos/serviços nas categorias: #{catalog_categories}. Use search_catalog para buscar." : ''

    "#{base}\n\nSeu nome é #{@inbox.ai_name.presence || 'Assistente'}." \
      "\n[DATA/HORA]: #{date_info}" \
      "\n[CLIENTE]: Nome: #{contact_name}. WhatsApp: #{contact_phone}." \
      "#{teams_info}" \
      "#{catalog_info}" \
      "\n[REGRA GERAL]: Responda sempre de forma natural, humanizada e no mesmo idioma do cliente."
  end

  def build_message_history
    @conversation.messages
                 .where(message_type: [:incoming, :outgoing])
                 .where(private: false)
                 .order(created_at: :asc)
                 .last(20)
                 .map do |msg|
      role = msg.message_type == 'incoming' ? 'user' : 'assistant'
      { role: role, content: msg.content.presence || '📎 [Mídia]' }
    end
  end

  def defined_tools
    [
      search_catalog_tool,
      send_item_photos_tool,
      create_appointment_tool,
      qualify_lead_tool,
      apply_label_tool,
      route_to_team_tool
    ]
  end

  def search_catalog_tool
    {
      type: 'function',
      function: {
        name: 'search_catalog',
        description: 'Busca produtos ou serviços no catálogo do negócio. Use para responder perguntas sobre o que é oferecido, preços e disponibilidade.',
        parameters: {
          type: 'object',
          properties: {
            query: { type: 'string', description: 'Nome ou parte do nome do produto/serviço' },
            category: { type: 'string', description: 'Categoria para filtrar (ex: Corte, Pizza, Consulta)' },
            max_price: { type: 'number', description: 'Preço máximo em reais' }
          }
        }
      }
    }
  end

  def send_item_photos_tool
    {
      type: 'function',
      function: {
        name: 'send_item_photos',
        description: 'Envia as fotos de um produto ou serviço do catálogo para o cliente. Use somente quando o item tiver fotos disponíveis.',
        parameters: {
          type: 'object',
          properties: {
            item_id: { type: 'integer', description: 'ID do item do catálogo retornado por search_catalog' }
          },
          required: ['item_id']
        }
      }
    }
  end

  def create_appointment_tool
    {
      type: 'function',
      function: {
        name: 'create_appointment',
        description: 'Cria um agendamento para o cliente. Use após o cliente confirmar data e horário.',
        parameters: {
          type: 'object',
          properties: {
            catalog_item_id: { type: 'integer', description: 'ID do serviço/produto que será agendado (opcional)' },
            date: { type: 'string', description: 'Data no formato YYYY-MM-DD' },
            time: { type: 'string', description: 'Horário no formato HH:MM' },
            notes: { type: 'string', description: 'Observações adicionais do agendamento' }
          },
          required: ['date', 'time']
        }
      }
    }
  end

  def qualify_lead_tool
    {
      type: 'function',
      function: {
        name: 'qualify_lead',
        description: 'Registra a intenção e temperatura do lead após entender o que ele precisa. Use quando tiver informações suficientes sobre o interesse do cliente.',
        parameters: {
          type: 'object',
          properties: {
            temperature: { type: 'string', enum: %w[Frio Morno Quente], description: 'Frio = só pesquisando; Morno = interessado; Quente = quer fechar logo' },
            intention: { type: 'string', description: 'Descrição do que o cliente busca/precisa' }
          },
          required: %w[temperature intention]
        }
      }
    }
  end

  def apply_label_tool
    {
      type: 'function',
      function: {
        name: 'apply_label',
        description: 'Aplica uma etiqueta na conversa para classificar o lead. Use para organizar o atendimento.',
        parameters: {
          type: 'object',
          properties: {
            label: { type: 'string', description: 'Nome da etiqueta a aplicar (ex: lead_quente, agendado, pendente, com_atendente)' }
          },
          required: ['label']
        }
      }
    }
  end

  def route_to_team_tool
    teams = @conversation.account.teams.pluck(:name)
    {
      type: 'function',
      function: {
        name: 'route_to_team',
        description: 'Transfere a conversa para uma equipe humana. Use quando o cliente pedir atendimento humano ou quando o assunto fugir da sua competência.',
        parameters: {
          type: 'object',
          properties: {
            team_name: { type: 'string', enum: teams.presence || [''], description: 'Nome exato da equipe para onde transferir' },
            reason: { type: 'string', description: 'Motivo da transferência' }
          },
          required: ['team_name']
        }
      }
    }
  end

  def handle_response(response, messages)
    max_rounds = 4
    current_response = response

    max_rounds.times do
      choice = current_response.dig('choices', 0, 'message')
      return choice['content'] unless choice['tool_calls']

      tool_results = choice['tool_calls'].map do |tc|
        fn = tc.dig('function', 'name')
        args = JSON.parse(tc.dig('function', 'arguments'))
        result = execute_tool(fn, args)
        { tool_call: tc, name: fn, result: result.to_s }
      end

      messages << { role: 'assistant', content: nil, tool_calls: choice['tool_calls'] }
      tool_results.each do |tr|
        messages << { role: 'tool', tool_call_id: tr[:tool_call]['id'], name: tr[:name], content: tr[:result] }
      end

      current_response = @client.chat(
        parameters: {
          model: 'gpt-4o',
          messages: [{ role: 'system', content: build_system_prompt }] + messages,
          tools: defined_tools,
          tool_choice: 'auto',
          temperature: @inbox.ai_temperature || 0.7
        }
      )
    end

    current_response.dig('choices', 0, 'message', 'content')
  end

  def execute_tool(name, args)
    account = @conversation.account
    contact = @conversation.contact

    case name
    when 'search_catalog'
      items = account.catalog_items.active
      items = items.where('name ILIKE ? OR description ILIKE ?', "%#{args['query']}%", "%#{args['query']}%") if args['query'].present?
      items = items.by_category(args['category']) if args['category'].present?
      items = items.where('price <= ?', args['max_price']) if args['max_price'].present?
      items = items.ordered.limit(5)

      return 'Nenhum produto ou serviço encontrado com esses critérios.' if items.empty?

      items.map do |i|
        has_photos = i.photos.attached?
        desc = "- ID #{i.id}: #{i.name}"
        desc += " | Categoria: #{i.category}" if i.category.present?
        desc += " | Preço: #{i.price_formatted}" if i.price
        desc += " | Duração: #{i.duration_minutes} min" if i.duration_minutes.present?
        desc += " | #{i.description.truncate(200)}" if i.description.present?
        desc += has_photos ? ' [TEM_FOTOS: SIM — pode oferecer enviar fotos com send_item_photos]' : ' [TEM_FOTOS: NÃO]'
        desc
      end.join("\n")

    when 'send_item_photos'
      item = account.catalog_items.find_by(id: args['item_id'])
      return 'Item não encontrado.' unless item
      return 'Este item não possui fotos cadastradas.' unless item.photos.attached?

      Thread.new do
        begin
          baileys_service = Whatsapp::Providers::WhatsappBaileysService.new(whatsapp_channel: @inbox.channel)
          jid = contact.identifier || contact.phone_number&.gsub(/\D/, '')
          jid = "#{jid}@s.whatsapp.net" unless jid.include?('@')

          item.photos.first(5).each_with_index do |photo, idx|
            caption = idx.zero? ? "Veja as fotos de #{item.name}:" : ''
            url = Rails.application.routes.url_helpers.rails_blob_url(photo, host: ENV['FRONTEND_URL'])
            baileys_service.send_message(jid, caption, media_url: url)
            sleep 2
          end
        rescue StandardError => e
          Rails.logger.error("Erro ao enviar fotos do item: #{e.message}")
        end
      end
      "Fotos de #{item.name} enviadas ao cliente."

    when 'create_appointment'
      end_time = begin
        args['time'].present? ? (Time.parse(args['time']) + (args.dig('duration_minutes') || 60).minutes).strftime('%H:%M') : nil
      rescue StandardError
        nil
      end

      appointment = AiAppointment.create!(
        account: account,
        contact: contact,
        catalog_item_id: args['catalog_item_id'],
        assignee_id: @conversation.assignee_id,
        appointment_date: args['date'],
        start_time: args['time'],
        end_time: end_time,
        notes: args['notes'],
        status: 'scheduled'
      )

      execute_tool('apply_label', { 'label' => 'agendado' })
      "Agendamento criado com sucesso! Data: #{args['date']} às #{args['time']}. ID: #{appointment.id}."

    when 'qualify_lead'
      attrs = { additional_attributes: contact.additional_attributes.merge('temperature' => args['temperature'], 'intention' => args['intention']) }
      contact.update!(attrs)
      "Lead qualificado: temperatura=#{args['temperature']}, intenção=#{args['intention']}."

    when 'apply_label'
      label_name = args['label'].to_s.strip.downcase
      label = account.labels.find_or_create_by!(title: label_name) do |l|
        l.color = '#6b7280'
        l.description = "Aplicada pela IA"
      end

      existing = @conversation.label_list
      unless existing.include?(label_name)
        @conversation.update!(label_list: existing + [label_name])
      end
      "Etiqueta '#{label_name}' aplicada."

    when 'route_to_team'
      team = account.teams.find_by(name: args['team_name'])
      return "Equipe '#{args['team_name']}' não encontrada." unless team

      @conversation.update!(team_id: team.id)
      pause_ai_permanently
      "Conversa transferida para a equipe #{team.name}. IA pausada."

    else
      'Ferramenta não implementada.'
    end
  rescue StandardError => e
    Rails.logger.error("AiAssistantService tool error: #{e.message}")
    "Erro ao executar ferramenta: #{e.message}"
  end

  def split_into_messages(text)
    return [text] if text.length < 80

    response = @client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: "Divida o texto em mensagens menores como um humano enviaria no WhatsApp. " \
                     "Retorne JSON com campo \"mensagens\" (array de strings). " \
                     "Máximo 5 partes. Nunca quebre listas. Máximo 4 frases por mensagem."
          },
          { role: 'user', content: text }
        ],
        temperature: 0.3
      }
    )

    json_str = response.dig('choices', 0, 'message', 'content')
    JSON.parse(json_str)['mensagens'] || [text]
  rescue StandardError
    [text]
  end

  def pause_ai_permanently(expires_in: nil)
    jid = @conversation.contact.identifier || @conversation.contact.phone_number
    return unless jid

    if expires_in
      Rails.cache.write("ai_paused_#{@inbox.id}_#{jid}", true, expires_in: expires_in)
      Rails.cache.write("ai_paused_ttl_#{@inbox.id}_#{jid}", (Time.current + expires_in).to_i, expires_in: expires_in)
    else
      Rails.cache.write("ai_paused_#{@inbox.id}_#{jid}", true)
    end
  end
end
