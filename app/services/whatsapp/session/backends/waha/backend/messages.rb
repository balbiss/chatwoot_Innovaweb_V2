# The messaging half of the WAHA backend.
module Whatsapp::Session::Backends::Waha::Backend::Messages
  # Content kind -> the `/api/send*` endpoint. A voice note is sent through `/sendVoice`
  # (which can transcode on the way in) rather than `/sendFile`, matching how the uazapi
  # backend treats `ptt` as a type of its own.
  ENDPOINTS = {
    'image' => '/api/sendImage', 'video' => '/api/sendVideo', 'document' => '/api/sendFile',
    'sticker' => '/api/sendImage'
  }.freeze

  def send_message(command)
    content = command.content
    case content&.wire_type
    when 'text' then send_text(command, content)
    when 'media' then send_media(command, content)
    else raise Whatsapp::Session::Errors::InvalidPayload, "waha cannot send #{content&.wire_type.inspect}"
    end
  end

  # WAHA reads unread messages by count/age, not by an explicit list of ids (confirmed
  # against the live schema: `POST /chats/{chatId}/messages/read` takes no message id
  # parameter at all) — so this reads everything unread in the chat the caller named,
  # which is the closest match to "the agent opened this conversation" that the provider
  # offers.
  def mark_read(command)
    return nil if command.chat.nil?

    client.post("/api/#{session_name}/chats/#{chat_id(command.chat)}/messages/read")
    nil
  end

  # The url in `ref` is always fetchable here: WAHA hands back a plain https url on the
  # inbound message itself (`media.url`), never an encrypted blob that needs a decrypt
  # round trip the way uazapi's does, so there is no provider call in this path at all.
  def download_media(command)
    ref = command.ref
    raise Whatsapp::Session::Errors::MediaUnavailable, 'waha message carries no media url' unless ref&.fetchable?

    fetch(ref.url, mime: ref.mime)
  end

  private

  def send_text(command, content)
    body = base_body(command).merge(text: content.body.to_s)
    send_result(client.post('/api/sendText', body), command)
  end

  # `MessageVoiceRequest` has no `caption` field at all (confirmed against the live
  # schema) — WAHA's validation pipe rejects unknown properties, so it is left out of
  # that body entirely rather than sent and compacted away only when blank.
  def send_media(command, content)
    body = base_body(command).merge(file: media_file(content))
    if content.voice_note
      send_result(client.post('/api/sendVoice', body.merge(convert: true),
                              timeout: Whatsapp::Session::Backends::Waha::Client::UPLOAD_TIMEOUT), command)
    else
      endpoint = ENDPOINTS.fetch(content.kind, '/api/sendFile')
      send_result(client.post(endpoint, body.merge(caption: content.caption.presence),
                              timeout: Whatsapp::Session::Backends::Waha::Client::UPLOAD_TIMEOUT), command)
    end
  end

  def base_body(command)
    body = { chatId: chat_id(command.to), session: session_name }
    quoted = command.quoted&.id
    body[:reply_to] = quoted if quoted.present?
    body
  end

  # A url the provider fetches itself (`RemoteFile`), same reasoning as the uazapi
  # backend: the ref of an outbound attachment is always a url this app serves.
  def media_file(content)
    url = content.ref&.url
    raise Whatsapp::Session::Errors::InvalidPayload, 'outbound media has no url' if url.blank?

    { mimetype: content.mime.presence, filename: content.filename.presence, url: url }.compact
  end

  # WHAT IS PROVEN (confirmed live, 2026-08-22, against a real send): despite `WAMessage.id`
  # being documented as a plain string, the real `/api/sendText` response on this WEBJS
  # session returns it as an object (`{fromMe, remote, id, _serialized}`) — the
  # `_serialized` field is the flat id form every other part of this backend expects.
  # `timestamp` is confirmed in seconds (matches the documented `WAMessage.timestamp`),
  # and `Whatsapp::Session::Outbound::MessageSender` divides `SendResult#timestamp` by
  # 1000 expecting milliseconds — sent through unconverted, a real outgoing message was
  # stored with `external_created_at` truncated to a small number that rendered as
  # "Jan 21 1970" in the dashboard.
  def send_result(result, command)
    result = result.to_h
    id = result['id']
    message_id = id.is_a?(Hash) ? id['_serialized'] : id
    timestamp = result['timestamp']
    model::SendResult.new(
      message_id: message_id, timestamp: (timestamp.to_i * 1000 if timestamp.present?),
      client_ref: command.try(:client_ref)
    )
  end
end
