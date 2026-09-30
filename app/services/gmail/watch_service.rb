class Gmail::WatchService
  def initialize(sync_state)
    @sync_state = sync_state
  end

  def perform
    topic_name = ENV.fetch('GMAIL_PUBSUB_TOPIC')
    response = Gmail::Client.new(@sync_state.channel).watch(topic_name)

    @sync_state.update!(
      history_id: @sync_state.history_id || response.fetch('historyId'),
      watch_expires_at: Time.zone.at(response.fetch('expiration').to_i / 1000)
    )
  rescue OAuth2::Error => e
    @sync_state.channel.authorization_error!
    raise e
  end
end
