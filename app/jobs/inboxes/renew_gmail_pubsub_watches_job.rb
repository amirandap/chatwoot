class Inboxes::RenewGmailPubsubWatchesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    GmailPubsubSyncState.active.includes(:channel).find_each do |sync_state|
      next if sync_state.channel.reauthorization_required?

      Gmail::WatchService.new(sync_state).perform
    rescue StandardError => e
      sync_state.update_column(:last_error, "#{e.class}: #{e.message}")
      ChatwootExceptionTracker.new(e, account: sync_state.channel.account).capture_exception
    end
  end
end
