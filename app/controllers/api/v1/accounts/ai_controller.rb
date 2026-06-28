class Api::V1::Accounts::AiController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_conversation, only: [:ai_status, :resume_ai]

  def ai_status
    inbox = @conversation.inbox
    jid = @conversation.contact.identifier || @conversation.contact.phone_number
    paused = Rails.cache.exist?("ai_paused_#{inbox.id}_#{jid}")
    remaining = nil

    if paused
      ttl = Rails.cache.read("ai_paused_ttl_#{inbox.id}_#{jid}")
      remaining = ttl ? [ttl - Time.current.to_i, 0].max : nil
    end

    render json: { paused: paused, remaining_seconds: remaining }
  end

  def resume_ai
    inbox = @conversation.inbox
    jid = @conversation.contact.identifier || @conversation.contact.phone_number
    Rails.cache.delete("ai_paused_#{inbox.id}_#{jid}")
    Rails.cache.delete("ai_paused_ttl_#{inbox.id}_#{jid}")
    render json: { success: true }
  end

  def generate_prompt
    wizard_data = params.require(:wizard).permit(
      :business_name, :segment, :services, :tone, :ai_name,
      :working_hours, :can_give_discount, :can_mention_competitors,
      :transfer_conditions, :never_do, :differentials, :faq,
      :greeting_uses_name, :greeting_uses_time
    )

    available_teams = Current.account.teams.pluck(:name).join(', ')

    meta_prompt = <<~PROMPT
      Você é especialista em criar system prompts para assistentes virtuais de WhatsApp.
      Com base nas informações abaixo, crie um system prompt completo, profissional e humanizado.

      O prompt DEVE incluir obrigatoriamente:
      1. Nome e personalidade da assistente
      2. Tom de voz e estilo de escrita
      3. O que pode e não pode fazer
      4. Como qualificar o interesse do cliente
      5. Como apresentar os produtos/serviços do catálogo de forma natural e persuasiva
      6. Como conduzir para o agendamento
      7. Quando transferir para cada equipe disponível: #{available_teams.presence || 'Nenhuma equipe cadastrada'}
      8. Instrução para responder somente no idioma que o cliente usar

      DADOS DO NEGÓCIO:
      Nome: #{wizard_data[:business_name]}
      Segmento: #{wizard_data[:segment]}
      Serviços/Produtos: #{wizard_data[:services]}
      Tom desejado: #{wizard_data[:tone]}
      Nome da assistente: #{wizard_data[:ai_name] || 'Assistente'}
      Horário de funcionamento: #{wizard_data[:working_hours]}
      Pode dar desconto: #{wizard_data[:can_give_discount] == 'true' ? 'Sim' : 'Não'}
      Pode falar de concorrentes: #{wizard_data[:can_mention_competitors] == 'true' ? 'Sim' : 'Não'}
      Quando transferir para humano: #{wizard_data[:transfer_conditions]}
      O que NUNCA deve fazer: #{wizard_data[:never_do]}
      Diferenciais do negócio: #{wizard_data[:differentials]}
      Perguntas frequentes: #{wizard_data[:faq]}

      Retorne APENAS o texto do system prompt, sem explicações adicionais.
    PROMPT

    api_key = ENV['OPENAI_API_KEY']
    return render json: { error: 'OPENAI_API_KEY não configurada' }, status: :unprocessable_entity if api_key.blank?

    client = OpenAI::Client.new(access_token: api_key)
    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: [{ role: 'user', content: meta_prompt }],
        temperature: 0.7
      }
    )

    prompt = response.dig('choices', 0, 'message', 'content')
    render json: { prompt: prompt }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_conversation
    @conversation = Current.account.conversations.find(params[:conversation_id])
  end
end
