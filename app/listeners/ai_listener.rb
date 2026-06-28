class AiListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless should_process_ai?(message)

    AiResponseJob.perform_later(message.id)
  end

  def message_created_sync(event)
    message = extract_message_and_account(event)[0]
    return unless should_process_ai?(message)

    # Pausa a IA quando um agente humano responde
    pause_ai_on_agent_reply(message)
  end

  private

  def should_process_ai?(message)
    return false unless message.message_type == 'incoming'
    return false if message.private

    inbox = message.inbox
    return false unless inbox.ai_enabled? && inbox.ai_prompt.present?
    return false unless inbox.channel.is_a?(Channel::Whatsapp) && inbox.channel.provider == 'baileys'

    contact = message.conversation.contact
    jid = contact.identifier || contact.phone_number
    return false if Rails.cache.exist?("ai_paused_#{inbox.id}_#{jid}")

    true
  end

  def pause_ai_on_agent_reply(message)
    return unless message.message_type == 'outgoing'
    return if message.private

    inbox = message.inbox
    return unless inbox.ai_enabled?

    contact = message.conversation.contact
    jid = contact.identifier || contact.phone_number
    return unless jid

    expires = 30.minutes
    Rails.cache.write("ai_paused_#{inbox.id}_#{jid}", true, expires_in: expires)
    Rails.cache.write("ai_paused_ttl_#{inbox.id}_#{jid}", (Time.current + expires).to_i, expires_in: expires)
  end
end
