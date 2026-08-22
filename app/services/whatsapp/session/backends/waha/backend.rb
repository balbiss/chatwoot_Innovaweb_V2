# The `waha` provider: a WAHA instance (devlikeapro/waha) reached over HTTP, either
# self-hosted next to this deployment or run elsewhere by whoever administers the
# account. Unlike uazapi, WAHA sessions are provisioned BY this backend (`POST
# /api/sessions`), not brought pre-existing by the operator: an inbox owns its session
# end to end, the same way the `native` connector owns its own pairing.
#
# WHAT IS PROVEN. Verified against a live WAHA CORE instance on 22/08/2026: creating a
# session (`POST /api/sessions`, idempotent failure on a duplicate name — 422 "already
# exists, use PUT"), starting it (`POST /sessions/{s}/start`, documented idempotent),
# polling status (`GET /sessions/{s}`, `STOPPED -> STARTING -> SCAN_QR_CODE -> WORKING`),
# fetching the QR (`GET /{s}/auth/qr` — returns raw `image/png` UNLESS `Accept:
# application/json` is sent, in which case it answers `{mimetype, data}`; the client sends
# that header on every request), sending text (`POST /sendText`) and checking a number
# (`GET /checkNumberStatus`). Group management, reactions, edit and revoke are NOT
# declared: `POST /{s}/auth/request-code` (code pairing) answers `201` with no documented
# body and no confirmed way to read the code back, so it is left out rather than shipped
# as a button that fails in the agent's face.
class Whatsapp::Session::Backends::Waha::Backend < Whatsapp::Session::Backend
  include Whatsapp::Session::Backends::Waha::Backend::Messages

  MAX_MEDIA_BYTES = 100.megabytes

  # WAHA's own `SessionInfo.status` -> canonical connection.
  CONNECTIONS = {
    'STOPPED' => 'close', 'FAILED' => 'close',
    'STARTING' => 'connecting', 'SCAN_QR_CODE' => 'connecting',
    'PASSKEY_REQUIRED' => 'connecting', 'PASSKEY_CONFIRMATION_REQUIRED' => 'connecting',
    'WORKING' => 'open'
  }.freeze

  # The events this inbox subscribes to on session creation — only what the translator
  # actually turns into canonical events. WAHA does not push the QR over the webhook (it
  # has to be polled, see `state_polling?`), so no event is asked for that purpose.
  WEBHOOK_EVENTS = %w[session.status message message.ack message.revoked message.edited].freeze

  class << self
    def provider_key
      'waha'
    end

    def capabilities
      Whatsapp::Session::Registry.descriptor('waha').capabilities
    end

    # The QR rotates and WAHA's webhook never carries it, only `GET .../auth/qr` does, so
    # an inbox that is not polled sits on a code that stopped working.
    def state_polling?
      true
    end

    # Whether the instance is somebody else's host is not something its address can
    # answer, the same reasoning the uazapi backend documents — WAHA ships as open source,
    # so unlike uazapi it is routinely run next to Chatwoot on the deployment's own
    # network (this very deployment does, at waha.inoovaweb.com.br, on the same Swarm
    # overlay). The base default (`false`, self-hosted) is left as is rather than
    # overridden to `true`, so a future internal-address optimization is not ruled out;
    # today `webhook_url` always uses the public address regardless, which is correct in
    # both cases.
    def hosted?(_channel)
      false
    end

    def instance_fingerprint(channel)
      config = channel.provider_config || {}
      return if config['base_url'].blank? || config['session_id'].blank?

      Digest::SHA256.hexdigest("#{config['base_url'].to_s.chomp('/')}\n#{config['session_id']}")
    end

    def translator
      Whatsapp::Session::Backends::Waha::WebhookTranslator
    end

    def validate_config(provider_config)
      config = (provider_config || {}).with_indifferent_access
      keys = []
      keys << 'base_url' unless reachable_http_url?(config[:base_url])
      keys << 'api_key' if config[:api_key].blank?
      keys
    end

    private

    def reachable_http_url?(value)
      return false unless address.http_url?(value)

      SafeFetch.allow_private_network? || !address.url?(value)
    end

    def address = Whatsapp::Session::PrivateAddress
  end

  def model = Whatsapp::Session::Model
  def commands = Whatsapp::Session::Model::Commands

  def client
    @client ||= Whatsapp::Session::Backends::Waha::Client.new(
      base_url: provider_config['base_url'], api_key: provider_config['api_key']
    )
  end

  # `provider_config['session_id']` is what `ChannelExtension#ensure_webhook_verify_token`
  # generates for every session-layer inbox — a `SecureRandom.uuid`, minted once, never
  # shown, kept across ordinary saves — exactly so a backend that has to name its session
  # on the provider's side has something stable to name it with. A UUID passes WAHA's own
  # session-name validation (confirmed live: alphanumeric plus `-`/`_`, up to 54 chars).
  def session_name
    provider_config['session_id']
  end

  # --- session lifecycle -----------------------------------------------------------

  def connect(_command)
    create_or_update_session
    fetch_connection_state
  end

  def disconnect
    client.post("/api/sessions/#{session_name}/stop")
    nil
  end

  # WAHA has no "unpair without deleting the session" call the same way uazapi's
  # `/instance/logout` answers 405 — logging out here drops the session's credentials on
  # the provider's side outright, which IS a real unpair. `unpairs?` is left at the base
  # `false` default anyway pending a live-verified round trip (stop -> logout -> reconnect
  # -> new QR), so a quarantined number is not silently offered a re-pair path that has
  # not been proven yet.
  def logout
    client.post("/api/sessions/#{session_name}/logout")
    nil
  end

  # A teardown: the inbox is being destroyed or converted. Unlike uazapi (whose instance
  # belongs to the customer and is never touched), this backend created the session, so
  # deleting it is the correct and complete cleanup — nothing is left registered on the
  # provider afterwards, which is why `release_registration` below is a no-op.
  def delete_session
    client.delete("/api/sessions/#{session_name}")
    nil
  rescue Whatsapp::Session::Errors::SessionNotFound
    nil
  end

  def release_registration = nil

  # Re-asserts the session's webhook config. Called when the address this deployment
  # hands out changes without the pairing itself changing — the same trigger uazapi's
  # `ensure_registration` answers, achieved here by the same `PUT` used to keep the
  # session's config current.
  def ensure_registration = create_or_update_session

  def fetch_connection_state
    connection_state(client.get("/api/sessions/#{session_name}"))
  end

  # --- presence and contacts -------------------------------------------------------

  def send_chat_presence(command)
    client.post("/api/#{session_name}/presence", { chatId: chat_id(command.chat), presence: chat_presence_of(command.state) })
    nil
  end

  def update_presence(command)
    client.post("/api/#{session_name}/presence", { presence: global_presence_of(command.state) })
    nil
  end

  def check_numbers(command)
    Array(command.phones).map do |phone|
      result = client.get('/api/checkNumberStatus', { phone: phone, session: session_name }).to_h
      model::NumberCheck.new(
        phone: phone, exists: result['numberExists'].present?,
        address: model::Address.parse(result['chatId'].presence || result['pn'])
      )
    end
  end

  def profile_picture_url(command)
    result = client.get("/api/#{session_name}/chats/#{chat_id(command.party)}/picture").to_h
    result['url'].presence
  rescue Whatsapp::Session::Errors::ProviderUnavailable
    # No picture set answers the same shape errors this client otherwise treats as an
    # outage; WAHA gives no distinct code for "none", so a failed lookup here reads as
    # "nothing to show" rather than propagating a hard error for what is a cosmetic field.
    nil
  end

  private

  # --- session provisioning ------------------------------------------------------------

  # Creates the session on first connect; on every later call (reconnect, or
  # `ensure_registration` re-pointing the webhook host) the create attempt answers 422
  # "already exists", and the config is instead pushed with `PUT`. Either way `start` is
  # called last, which the provider documents as idempotent, so a session that is already
  # `WORKING` is left exactly as it was.
  def create_or_update_session
    client.post('/api/sessions', { name: session_name, config: session_config })
  rescue Whatsapp::Session::Errors::Error
    client.put("/api/sessions/#{session_name}", { config: session_config })
  ensure
    client.post("/api/sessions/#{session_name}/start")
  end

  def session_config
    { webhooks: [{ url: webhook_url, events: WEBHOOK_EVENTS }] }
  end

  # Always the public address, whether or not this particular instance happens to share a
  # private network with Chatwoot: unlike Baileys' `INTERNAL_HOST_URL` optimization, WAHA
  # is not assumed to be ours to reach privately (see `hosted?` above), and the public
  # address always works.
  #
  # The path token is generated per inbox and never shown, same guarantee the uazapi
  # backend documents: a URL leaked through a proxy log is not on its own enough, because
  # the controller also checks the session name the body claims to be from.
  def webhook_url
    host = ENV.fetch('FRONTEND_URL', nil)
    "#{host.to_s.chomp('/')}/webhooks/whatsapp/session/waha/#{channel.id}/#{provider_config['webhook_verify_token']}"
  end

  # --- connection --------------------------------------------------------------------

  def connection_state(session_info)
    info = session_info.to_h
    status = info['status'].to_s
    connection = CONNECTIONS.fetch(status, 'close')
    model::ConnectionState.new(
      connection: connection,
      qr_data_url: (fetch_qr_data_url if connection == 'connecting' && status == 'SCAN_QR_CODE'),
      phone_number: (info.dig('me', 'id').to_s.split('@').first.presence if connection == 'open'),
      error: connection_error(status)
    )
  end

  def connection_error(status)
    'logged_out' if status == 'FAILED'
  end

  def fetch_qr_data_url
    qr = client.get("/api/#{session_name}/auth/qr").to_h
    "data:#{qr['mimetype']};base64,#{qr['data']}" if qr['data'].present?
  rescue Whatsapp::Session::Errors::Error
    # The QR has a short window (WAHA rotates it) and the next poll tries again; a miss
    # here must not turn into the connection itself reading as down.
    nil
  end

  # --- presence and addressing ---------------------------------------------------------

  # `Whatsapp::Session::Facade#toggle_typing_status` sends `composing`/`recording`/`paused`
  # (the same vocabulary the Baileys layer already uses); WAHA's `WAHASessionPresence.presence`
  # enum names the first of those `typing` instead (confirmed against the live schema) —
  # everything else already matches, so only that one value is translated.
  def chat_presence_of(state)
    state.to_s == 'composing' ? 'typing' : state.to_s
  end

  # `Whatsapp::Session::Facade#update_presence` sends the contract's own
  # `available`/`unavailable` (see `Facade::PRESENCE_STATES`); WAHA's global presence
  # enum has no such pair, only `online`/`offline`.
  def global_presence_of(state)
    state.to_s == 'available' ? 'online' : 'offline'
  end

  def chat_id(address)
    return if address.nil?

    address.phone? ? "#{address.id}@c.us" : address.to_jid
  end

  # --- media -------------------------------------------------------------------------

  # Same filtering as the uazapi backend's `fetch`: the url is the provider's own choice
  # (it arrives on the webhook, or on the message this ref was built from), so it is
  # resolved and refused unless public before Rails reads it.
  #
  # `headers` carries the API key: WAHA's own `media.url` (`.../api/files/...`) is served
  # by the same authenticated API, and a request without the key answers 401 — confirmed
  # live (2026-08-22, real inbound media from a test conversation came back marked
  # `is_unsupported` because this fetch had no credentials).
  def fetch(url, mime: nil)
    SafeFetch.fetch(url, max_bytes: MAX_MEDIA_BYTES, validate_content_type: false,
                         headers: { Whatsapp::Session::Backends::Waha::Client::API_KEY_HEADER => provider_config['api_key'] },
                         sensitive_headers: [Whatsapp::Session::Backends::Waha::Client::API_KEY_HEADER]) do |result|
      file = Tempfile.new('waha-media', binmode: true)
      IO.copy_stream(result.tempfile, file)
      file.rewind
      model::MediaPayload.new(io: file, mime: mime.presence || result.content_type, filename: result.filename, size: file.size)
    end
  rescue SafeFetch::FileTooLargeError => e
    raise Whatsapp::Session::Errors::MediaTooLarge, e.message
  rescue SafeFetch::HttpError, SafeFetch::UnsafeUrlError, SafeFetch::InvalidUrlError => e
    raise Whatsapp::Session::Errors::ProviderUnavailable, "waha media fetch failed: #{e.message}" if retryable_media?(e)

    raise Whatsapp::Session::Errors::MediaUnavailable, "waha media is gone: #{e.message}"
  rescue SafeFetch::Error, *Whatsapp::Session::Backends::Waha::Client::TRANSPORT_ERRORS => e
    raise Whatsapp::Session::Errors::ProviderUnavailable, "waha media fetch failed: #{e.message}"
  end

  def retryable_media?(error)
    status = error.message.to_i
    status >= 500 || status == 429
  end
end
