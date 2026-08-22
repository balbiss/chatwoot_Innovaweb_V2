# Where a `waha` session delivers its events.
#
# Unlike uazapi's webhook body (which echoes the instance token back as a second factor),
# WAHA's envelope carries no credential at all — just `{id, timestamp, session, engine,
# event, payload, me, environment}` (confirmed against the live schema, 22/08/2026). The
# per-inbox path token generated at connect time is therefore the only secret this
# controller can check; `WebhookTranslator#this_session?` adds a second, weaker layer by
# refusing a body whose `session` name does not match the one this inbox is configured
# for. WAHA does support HMAC-signed webhooks (`config.webhooks[].hmac`); wiring that in
# as a real second factor is a follow-up, not shipped here because it has not been
# exercised against a live instance yet.
class Webhooks::Whatsapp::WahaController < ActionController::API
  def process_payload
    return head :not_found if channel.blank?
    return head :unauthorized unless authentic?

    Webhooks::WhatsappSessionEventsJob.perform_later(channel, event_payload,
                                                     Whatsapp::Session::Registry.instance_fingerprint(channel))
    head :ok
  end

  private

  def channel
    return @channel if defined?(@channel)

    @channel = Channel::Whatsapp.find_by(id: params[:channel_id], provider: 'waha')
  end

  def authentic?
    matches?(params[:webhook_token], channel.provider_config['webhook_verify_token'])
  end

  # Constant time, and never against a blank expectation: an inbox saved without its
  # token would otherwise accept anything that also sends nothing.
  def matches?(given, expected)
    return false if given.blank? || expected.blank?

    ActiveSupport::SecurityUtils.secure_compare(given.to_s, expected.to_s)
  end

  def event_payload
    request.request_parameters
  end
end
