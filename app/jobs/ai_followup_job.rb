class AiFollowupJob < ApplicationJob
  queue_as :low

  def perform
    Inbox.where(ai_followup_enabled: true).find_each do |inbox|
      process_inbox(inbox)
    end
  end

  private

  def process_inbox(inbox)
    wait_minutes = inbox.ai_followup_wait_minutes || 120
    max_attempts = inbox.ai_followup_max_attempts || 3
    threshold = wait_minutes.minutes.ago

    inbox.conversations
         .where(status: :open)
         .where('last_activity_at < ?', threshold)
         .find_each do |conversation|
      last_msg = conversation.messages.where(private: false).order(created_at: :asc).last
      next if last_msg.nil?
      next if last_msg.message_type == 'incoming'

      if conversation.ai_followup_count.to_i < max_attempts
        generate_and_send_followup(inbox, conversation)
      else
        mark_as_inactive(inbox, conversation)
      end
    end
  end

  def generate_and_send_followup(inbox, conversation)
    api_key = ENV['OPENAI_API_KEY']
    return unless api_key.present?

    client = OpenAI::Client.new(access_token: api_key)

    history = conversation.messages
                          .where(private: false)
                          .order(created_at: :asc)
                          .last(15)
                          .map do |m|
      role = m.message_type == 'incoming' ? 'user' : 'assistant'
      { role: role, content: m.content.presence || '📎 [Mídia]' }
    end

    base_prompt = inbox.ai_prompt.presence || 'Você é uma assistente virtual.'
    system_prompt = <<~PROMPT
      #{base_prompt}

      [INSTRUÇÃO DE FOLLOW-UP]
      O cliente não respondeu há algum tempo.
      Crie UMA ÚNICA MENSAGEM MUITO CURTA (máximo 15 palavras) para retomar o contato.
      Seja natural, como se o cliente tivesse simplesmente esquecido de responder.
      NUNCA se apresente novamente. NUNCA mande textão.
      RETORNE APENAS O TEXTO DA MENSAGEM.
    PROMPT

    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: history + [{ role: 'system', content: system_prompt }],
        temperature: 0.7
      }
    )

    text = response.dig('choices', 0, 'message', 'content')
    return unless text.present?

    send_message(inbox, conversation, text)
    conversation.update_columns(
      ai_followup_count: conversation.ai_followup_count.to_i + 1,
      last_activity_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("AiFollowupJob error for conversation #{conversation.id}: #{e.message}")
  end

  def mark_as_inactive(inbox, conversation)
    closing_msg = inbox.ai_followup_closing_message
    send_message(inbox, conversation, closing_msg) if closing_msg.present?

    conversation.update_columns(status: :resolved, ai_followup_count: 0)

    Note.create!(
      account: conversation.account,
      contact: conversation.contact,
      user_id: conversation.assignee_id || conversation.account.users.first&.id,
      content: "IA realizou #{inbox.ai_followup_max_attempts || 3} tentativas de follow-up sem resposta. Conversa encerrada automaticamente."
    )
  rescue StandardError => e
    Rails.logger.error("AiFollowupJob mark_inactive error: #{e.message}")
  end

  def send_message(inbox, conversation, text)
    channel = inbox.channel
    return unless channel.is_a?(Channel::Whatsapp) && channel.provider == 'baileys'

    baileys = Whatsapp::Providers::WhatsappBaileysService.new(whatsapp_channel: channel)
    contact = conversation.contact
    jid = contact.identifier || contact.phone_number&.gsub(/\D/, '')
    jid = "#{jid}@s.whatsapp.net" unless jid&.include?('@')

    baileys.send_message(jid, text)

    conversation.messages.create!(
      account: conversation.account,
      message_type: :outgoing,
      content: text,
      content_type: :text,
      sender: nil,
      private: false
    )
  end
end
