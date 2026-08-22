# One webhook body from this provider, turned into canonical events.
#
# WAHA wraps every event in the same envelope (confirmed against the live schema
# published by waha.inoovaweb.com.br, 22/08/2026): `{id, timestamp, session, engine,
# event, payload, me, environment}`. `event` names the wire type directly (`message`,
# `session.status`, `message.ack`, ...), which is far more consistent than uazapi's
# `EventType`/`state`/`event` split, so this translator is a straight dispatch on it.
class Whatsapp::Session::Backends::Waha::WebhookTranslator
  # WAHA's numeric ack, standard WhatsApp semantics: -1 failed, 0 pending (not a receipt
  # yet), 1 sent to server (not surfaced as a receipt either — Chatwoot only cares once it
  # left our own device), 2 delivered, 3 read, 4 played (voice notes).
  ACK_RECEIPTS = { 2 => 'delivered', 3 => 'read', 4 => 'played', -1 => 'failed' }.freeze

  attr_reader :channel, :body

  def initialize(channel, payload)
    @channel = channel
    @body = (payload || {}).to_h.with_indifferent_access
  end

  def perform
    return [] unless this_session?

    case body[:event]
    when 'session.status' then [connection].compact
    when 'message' then [message].compact
    when 'message.ack' then [receipt].compact
    when 'message.revoked' then [revoked].compact
    when 'message.edited' then [edited].compact
    else []
    end
  end

  private

  # The session name the body says it came from, against `provider_config['session_id']`
  # (see `Backend#session_name`). Same reasoning as the uazapi translator: a body is
  # authenticated when it arrives and dispatched later, and an inbox re-pointed at a
  # different WAHA session in between must not file the old session's messages under the
  # new one.
  def this_session?
    sent_from = body[:session].to_s
    configured = channel.provider_config['session_id'].to_s
    sent_from.blank? || configured.blank? || sent_from == configured
  end

  def model = Whatsapp::Session::Model
  def events = Whatsapp::Session::Model::Events
  def waha = Whatsapp::Session::Backends::Waha

  def event(payload)
    return if payload.nil?

    model::Event.build(payload, id: body[:id].presence, ts: body[:timestamp])
  end

  # --- connection --------------------------------------------------------------------

  def connection
    payload = (body[:payload] || {}).to_h.with_indifferent_access
    status = waha::Backend::CONNECTIONS.fetch(payload[:status].to_s, 'close')
    event(events::SessionState.new(state: status, phone: connected_phone(status)))
  end

  # WAHA does not push the QR over the webhook (confirmed: `state.change`/`session.status`
  # payloads carry no image). It has to be polled from `GET /{session}/auth/qr` while the
  # status is `SCAN_QR_CODE`, which is exactly what `state_polling?` on the backend exists
  # for — the same mechanism uazapi's rotating QR already relies on.
  def connected_phone(status)
    body.dig(:me, :id).to_s.split('@').first.presence if status == 'open'
  end

  # --- messages ----------------------------------------------------------------------

  def message
    payload = (body[:payload] || {}).to_h.with_indifferent_access
    return if payload[:id].blank?

    event(events::MessageReceived.new(message: inbound_message(payload)))
  end

  def inbound_message(payload)
    content = waha::ContentMapper.new(payload)
    model::InboundMessage.new(
      id: payload[:id], chat: chat_of(payload), sender: sender_of(payload), from_me: payload[:fromMe].present?,
      timestamp: (payload[:timestamp].to_i * 1000), content: content.perform, quoted_id: quoted_id(payload)
    )
  end

  # `from` is who the chat is with even for a message we sent (see WAMessage's own
  # description: "the Chat that this message was sent to, except if sent by the current
  # user" — for our own sends `to` is the chat instead), so the two are read together.
  def chat_of(payload)
    model::Address.parse(payload[:fromMe].present? ? payload[:to] : payload[:from])
  end

  # A group message's real author is `participant`; a 1:1 chat has none, and the chat
  # itself is the sender.
  #
  # `push_name` is NOT read from the documented `WAMessage` schema — there is no such
  # field on it. `_data.notifyName` is whatsapp-web.js's own internal shape (the engine
  # this deployment's WAHA session runs), read here as best effort; unlike the rest of
  # this mapper it has not been confirmed against a live webhook payload, only against
  # the library's known shape, so a contact whose name never appears in the CRM (rather
  # than crashing) is the acceptable failure mode if it is wrong.
  def sender_of(payload)
    participant = payload[:participant].presence
    model::Party.from_address(model::Address.parse(participant.presence || payload[:from]), push_name: push_name(payload))
  end

  def push_name(payload)
    (payload[:_data] || {}).to_h.with_indifferent_access[:notifyName].presence
  end

  # `replyTo.id` (documented field, unlike `push_name` above).
  def quoted_id(payload)
    (payload[:replyTo] || {}).to_h.with_indifferent_access[:id].presence
  end

  # --- receipts and revokes -----------------------------------------------------------

  def receipt
    payload = (body[:payload] || {}).to_h.with_indifferent_access
    type = ACK_RECEIPTS[payload[:ack].to_i]
    return if type.nil?

    event(
      events::MessageReceipt.new(
        chat: chat_of_ack(payload), message_ids: [payload[:id]].compact, type: type,
        participant: participant_of(payload)
      )
    )
  end

  def chat_of_ack(payload)
    model::Address.parse(payload[:fromMe].present? ? payload[:to] : payload[:from])
  end

  def participant_of(payload)
    model::Address.parse(payload[:participant].presence)
  end

  def revoked
    payload = (body[:payload] || {}).to_h.with_indifferent_access
    id = payload[:revokedMessageId].presence
    return if id.blank?

    before = (payload[:before] || {}).to_h.with_indifferent_access
    event(
      events::MessageRevoked.new(
        chat: chat_of(before.presence || payload), sender: sender_of(before.presence || payload),
        message_id: id, by: before[:fromMe].present? ? 'self' : 'contact'
      )
    )
  end

  # `WAMessageEditedBody` is flat, not an `{after, before}` pair like the revoked event:
  # it carries the new content directly, with `editedMessageId` naming the ORIGINAL
  # message this replaces (confirmed against the live schema — the shape does not match
  # `revoked`, despite the similar name).
  def edited
    payload = (body[:payload] || {}).to_h.with_indifferent_access
    target_id = payload[:editedMessageId].presence
    return if target_id.blank?

    event(
      events::MessageEdited.new(
        chat: chat_of(payload), sender: sender_of(payload), message_id: target_id,
        from_me: payload[:fromMe].present?, content: waha::ContentMapper.new(payload).perform
      )
    )
  end
end
