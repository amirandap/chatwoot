require 'base64'
require 'net/http'
require 'openssl'

class Webhooks::GmailPubsubController < ActionController::API
  before_action :verify_google_oidc!

  def receive
    notification = JSON.parse(Base64.decode64(params.require(:message).require(:data)))
    sync_state = GmailPubsubSyncState.find_by!(email_address: notification.fetch('emailAddress'))
    Inboxes::ProcessGmailHistoryJob.perform_later(sync_state.id)
    head :no_content
  rescue JSON::ParserError, KeyError, ActionController::ParameterMissing
    head :bad_request
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def verify_google_oidc!
    token = request.authorization.to_s.delete_prefix('Bearer ').presence
    return head :unauthorized if token.blank?

    header, payload, signature = token.split('.', 3).map { |part| JSON.parse(Base64.urlsafe_decode64(part)) rescue part }
    return head :unauthorized unless header.is_a?(Hash) && payload.is_a?(Hash) && signature.is_a?(String)
    return head :unauthorized unless valid_claims?(payload)

    certificate = certificates.fetch(header.fetch('kid'))
    verified = certificate.public_key.verify(OpenSSL::Digest::SHA256.new, Base64.urlsafe_decode64(signature), token.split('.', 3).first(2).join('.'))
    head :unauthorized unless verified
  rescue JSON::ParserError, KeyError, ArgumentError
    head :unauthorized
  end

  def valid_claims?(payload)
    payload['aud'] == ENV.fetch('GMAIL_PUBSUB_AUDIENCE') &&
      %w[accounts.google.com https://accounts.google.com].include?(payload['iss']) &&
      payload['exp'].to_i > Time.current.to_i &&
      payload['email'] == ENV.fetch('GMAIL_PUBSUB_SERVICE_ACCOUNT')
  end

  def certificates
    response = Net::HTTP.get_response(URI('https://www.googleapis.com/oauth2/v1/certs'))
    raise KeyError unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).transform_values { |certificate| OpenSSL::X509::Certificate.new(certificate) }
  end
end
