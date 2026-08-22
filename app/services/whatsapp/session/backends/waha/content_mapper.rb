# The body of one message from this provider, turned into canonical content.
#
# WHAT IS PROVEN: the published `WAMessage` schema (waha.inoovaweb.com.br, 22/08/2026)
# carries NO `type`/`messageType` discriminator field at all — only `hasMedia`+`media`,
# `location`, `vCards` and `body`. Kind is therefore inferred from which of those are
# present, and a media kind from `media.mimetype`, rather than switched on a type string
# the way the uazapi mapper does.
class Whatsapp::Session::Backends::Waha::ContentMapper
  MIME_KINDS = { 'image' => 'image', 'video' => 'video', 'audio' => 'audio' }.freeze
  STICKER_MIME = 'image/webp'.freeze

  attr_reader :message

  def initialize(message)
    @message = message
  end

  def perform
    return location if message[:location].present?
    return contacts if Array(message[:vCards]).present?
    return media if message[:hasMedia].present? && media_url.present?

    model::Content::Text.new(body: message[:body].to_s)
  end

  private

  def model = Whatsapp::Session::Model

  def media_url
    message.dig(:media, :url).presence
  end

  def mime = message.dig(:media, :mimetype).presence

  # No documented signal distinguishes a recorded voice note from an audio file share
  # (unlike the uazapi payload, which names a `ptt` media type outright) — `voice_note`
  # is left false rather than guessed, so a real audio file is never mislabeled as a
  # recording. The worst case is a voice note rendering as a plain audio attachment
  # instead of the dedicated player bubble, which is cosmetic, not a functional loss.
  def media
    model::Content::Media.new(
      kind: kind_of(mime), mime: mime, filename: message.dig(:media, :filename).presence,
      caption: message[:body].presence, voice_note: false, ref: model::MediaRef.url(media_url, mime: mime)
    )
  end

  def kind_of(mime)
    return 'sticker' if mime == STICKER_MIME

    prefix = mime.to_s.split('/').first
    MIME_KINDS.fetch(prefix, 'document')
  end

  def location
    location = (message[:location] || {}).to_h.with_indifferent_access
    model::Content::Location.new(
      latitude: location[:latitude], longitude: location[:longitude],
      name: location[:name].presence, address: location[:address].presence, live: location[:live].present?
    )
  end

  # `vCards` is a flat array of raw vcard strings (confirmed against the schema) — one
  # canonical contact card per entry, name pulled from the `FN:` line since the schema
  # gives no structured display name alongside it.
  def contacts
    model::Content::Contacts.new(
      contacts: Array(message[:vCards]).filter_map { |vcard| { 'display_name' => fn_of(vcard), 'vcard' => vcard }.compact if vcard.present? }
    )
  end

  def fn_of(vcard)
    vcard.to_s[/^FN:(.+)$/, 1]&.strip.presence
  end
end
