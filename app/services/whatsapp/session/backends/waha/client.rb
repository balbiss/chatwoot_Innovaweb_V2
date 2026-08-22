# The HTTP side of the `waha` provider: one self-hosted (or hosted) WAHA instance
# (devlikeapro/waha), reached with the base URL and the instance API key the operator
# pasted into the inbox form.
#
# Everything this class knows about the provider is transport: how to authenticate, what
# a failure means in canonical terms, and how long to wait. Which endpoints exist and
# what their answers mean belongs to the backend.
class Whatsapp::Session::Backends::Waha::Client
  # The API key travels in this header on every request, confirmed against a live
  # instance (waha.inoovaweb.com.br, WAHA CORE, 22/08/2026): a request without it answers
  # 401 with `{"message":"Unauthorized","statusCode":401}`.
  API_KEY_HEADER = 'X-Api-Key'.freeze

  TIMEOUT = 20
  UPLOAD_TIMEOUT = 60
  OPEN_TIMEOUT = 5

  # HTTP status -> contract error code, resolved to a class at raise time by
  # `Errors.build`. Only codes confirmed against a live instance are mapped; everything
  # else falls through to the generic 5xx/4xx split below, same as the uazapi client.
  #
  # WHAT IS PROVEN (22/08/2026, WAHA CORE): 401 without a key
  # (`{"message":"Unauthorized","statusCode":401}`), 404 for an unknown session
  # (`{"message":"Session not found","error":"Not Found","statusCode":404}`), 400 for a
  # payload the validation pipe rejects (`{"message":[...],"error":"Bad
  # Request","statusCode":400}`). Sending to a session that is not connected answers 422
  # with a DIFFERENT shape entirely (`{"error":"Session \"x\" does not exist","session":
  # "x"}`, no `statusCode` key) — see `detail` below, which reads both shapes.
  STATUS_CODES = {
    400 => 'invalid_payload',
    401 => 'unauthorized',
    403 => 'unauthorized',
    404 => 'session_not_found'
  }.freeze

  # Connection-level failures. Same list as the uazapi client: anything left out escapes
  # as itself and a caller that rescues this layer's own errors would let it through.
  TRANSPORT_ERRORS = [
    Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Net::HTTPBadResponse, Net::ProtocolError,
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
    Errno::ETIMEDOUT, Errno::EPIPE, EOFError, IOError, SocketError, OpenSSL::SSL::SSLError,
    HTTParty::Error, SsrfFilter::UnresolvedHostname, SsrfFilter::TooManyRedirects
  ].freeze

  attr_reader :base_url, :api_key

  def initialize(base_url:, api_key:)
    @base_url = base_url.to_s.chomp('/')
    @api_key = api_key.to_s
    raise Whatsapp::Session::Errors::InvalidConfig, 'waha inbox has no base url or api key' if @base_url.blank? || @api_key.blank?
  end

  def get(path, query = {})
    request(:get, path, query: query.compact)
  end

  def post(path, body = {}, timeout: TIMEOUT)
    request(:post, path, body: body.compact, timeout: timeout)
  end

  def put(path, body = {}, timeout: TIMEOUT)
    request(:put, path, body: body.compact, timeout: timeout)
  end

  def delete(path)
    request(:delete, path)
  end

  private

  def request(method, path, query: nil, body: nil, timeout: TIMEOUT)
    payload = body.to_json if body.present?
    status, answer = if SafeFetch.allow_private_network?
                       direct(method, path, query, payload, timeout)
                     else
                       filtered(method, path, query, payload, timeout)
                     end
    parse(status, answer, path)
  rescue *TRANSPORT_ERRORS => e
    raise Whatsapp::Session::Errors::ProviderUnavailable, "waha #{path} did not answer (#{e.class})"
  rescue SsrfFilter::Error => e
    raise Whatsapp::Session::Errors::InvalidConfig, "waha #{path} is not an address this deployment will call (#{e.class})"
  end

  # Same reasoning as the uazapi client's `filtered`: the base URL is typed by whoever
  # administers the account, so every address is resolved and refused unless public,
  # right at the moment of the call (a validation on the literal address cannot cover a
  # redirect).
  def filtered(method, path, query, payload, timeout)
    options = { open_timeout: OPEN_TIMEOUT, read_timeout: timeout, write_timeout: timeout }
    response = SsrfFilter.public_send(method, url(path), headers: headers, body: payload, params: query.presence,
                                                         sensitive_headers: [API_KEY_HEADER], http_options: options)
    [response.code.to_i, response.body]
  end

  # An operator who has opened the private network is running the instance next to
  # Chatwoot (the same instance this deployment already runs at waha.inoovaweb.com.br is
  # reached over the public internet, so this path is only for a self-hosted install that
  # chose to run WAHA on its own internal network).
  def direct(method, path, query, payload, timeout)
    options = { headers: headers, timeout: timeout, open_timeout: OPEN_TIMEOUT, no_follow: true }
    options[:query] = query if query.present?
    options[:body] = payload if payload.present?
    response = HTTParty.public_send(method, url(path), **options)
    [response.code, response.body]
  end

  def url(path)
    "#{base_url}#{path}"
  end

  # `Accept: application/json` matters specifically for the QR endpoint: without it, WAHA
  # answers with the raw `image/png` bytes instead of the `{mimetype, data}` JSON body
  # `parse` below expects (confirmed against a live instance, 22/08/2026).
  def headers
    { API_KEY_HEADER => api_key, 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  end

  def parse(status, answer, path)
    body = answer.presence && JSON.parse(answer)
    return body if status.between?(200, 299)

    raise Whatsapp::Session::Errors.build(code_for(status), "waha #{path} answered #{status}#{detail(body)}")
  rescue JSON::ParserError
    raise Whatsapp::Session::Errors::ProviderUnavailable, "waha #{path} answered #{status} with a body that is not json"
  end

  def code_for(status)
    STATUS_CODES[status] || (status >= 500 ? 'wa_error' : 'invalid_payload')
  end

  # Two different error shapes are confirmed on this provider (see STATUS_CODES above):
  # the Nest validation pipe answers `message` (a string or an array of strings), while
  # session-level errors answer `error` instead, with no `statusCode` at all. Both are
  # read here so neither shape is silently dropped.
  def detail(body)
    return nil unless body.is_a?(Hash)

    message = body['message']
    message = message.join(', ') if message.is_a?(Array)
    message ||= body['error']
    ": #{message}" if message.present?
  end
end
