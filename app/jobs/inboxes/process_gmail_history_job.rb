class Inboxes::ProcessGmailHistoryJob < MutexApplicationJob
  queue_as :scheduled_jobs
  retry_on LockAcquisitionError, wait: 15.seconds, attempts: 10

  def perform(sync_state_id)
    sync_state = GmailPubsubSyncState.find(sync_state_id)
    return if sync_state.channel.reauthorization_required?

    with_lock(lock_key(sync_state), 10.minutes) do
      Gmail::HistorySyncService.new(sync_state).perform
    end
  rescue OAuth2::Error => e
    sync_state&.channel&.authorization_error!
    raise e
  end

  private

  def lock_key(sync_state)
    "gmail-pubsub-history:#{sync_state.channel_id}"
  end
end
