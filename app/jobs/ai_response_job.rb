class AiResponseJob < ApplicationJob
  queue_as :default

  DEBOUNCE_SECONDS = 8

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    conversation = message.conversation
    inbox = conversation.inbox

    # Debounce: aguarda para capturar mensagens em sequência rápida
    sleep DEBOUNCE_SECONDS

    # Verifica se chegou mensagem mais nova depois do debounce
    last_msg = conversation.messages.where(message_type: :incoming, private: false).order(created_at: :asc).last
    return if last_msg&.id != message_id

    # Verifica se IA ainda está ativa
    contact = conversation.contact
    jid = contact.identifier || contact.phone_number
    return if Rails.cache.exist?("ai_paused_#{inbox.id}_#{jid}")

    service = AiAssistantService.new(inbox, conversation)
    texts = service.process_message
    return if texts.blank?

    channel = inbox.channel
    baileys = Whatsapp::Providers::WhatsappBaileysService.new(whatsapp_channel: channel)
    remote_jid = jid.include?('@') ? jid : "#{jid}@s.whatsapp.net"

    texts.each_with_index do |text, idx|
      baileys.send_message(remote_jid, text)

      conversation.messages.create!(
        account: conversation.account,
        message_type: :outgoing,
        content: text,
        content_type: :text,
        sender: nil,
        private: false
      )

      sleep 1.5 unless idx == texts.length - 1
    end
  rescue StandardError => e
    Rails.logger.error("AiResponseJob error for message #{message_id}: #{e.message}")
  end
end
