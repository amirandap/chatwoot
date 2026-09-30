require 'base64'

class Gmail::Client
  API_URL = 'https://gmail.googleapis.com/gmail/v1/users/me'.freeze

  class HistoryExpired < StandardError; end

  def initialize(channel)
    @channel = channel
  end

  def history(start_history_id, page_token: nil)
    get('/history', startHistoryId: start_history_id, pageToken: page_token, historyTypes: 'messageAdded')
  rescue Faraday::ResourceNotFound
    raise HistoryExpired
  end

  def message(message_id)
    get("/messages/#{message_id}", format: 'raw')
  rescue Faraday::ResourceNotFound
    nil
  end

  def messages(query:, page_token: nil)
    get('/messages', q: query, pageToken: page_token)
  end

  def profile
    get('/profile')
  end

  def watch(topic_name)
    response = connection.post('/watch', { topicName: topic_name, labelIds: %w[INBOX SENT] }.to_json)
    parse(response)
  end

  private

  def get(path, params = {})
    parse(connection.get(path, params))
  end

  def parse(response)
    raise Faraday::ResourceNotFound, response if response.status == 404
    raise "Gmail API request failed: #{response.status}" unless response.success?

    JSON.parse(response.body)
  end

  def connection
    @connection ||= Faraday.new(url: API_URL) do |faraday|
      faraday.request :authorization, 'Bearer', access_token
      faraday.headers['Content-Type'] = 'application/json'
      faraday.response :raise_error
      faraday.adapter Faraday.default_adapter
    end
  end

  def access_token
    Google::RefreshOauthTokenService.new(channel: @channel).access_token
  end
end
