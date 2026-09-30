require 'set'

class Gmail::HistorySyncService
  def initialize(sync_state)
    @sync_state = sync_state
    @client = Gmail::Client.new(sync_state.channel)
  end

  def perform
    raise ArgumentError, 'Gmail Pub/Sub sync has not been initialized' if @sync_state.history_id.blank?

    page_token = nil
    latest_history_id = @sync_state.history_id
    processed_message_ids = Set.new

    loop do
      response = @client.history(@sync_state.history_id, page_token: page_token)
      Array(response['history']).flat_map { |entry| Array(entry['messagesAdded']) }.each do |entry|
        message_id = entry.fetch('message').fetch('id')
        next if processed_message_ids.include?(message_id)

        processed_message_ids << message_id
        gmail_message = @client.message(message_id)
        import_message(@sync_state, gmail_message) if gmail_message.present?
      end
      latest_history_id = response.fetch('historyId')
      page_token = response['nextPageToken']
      break if page_token.blank?
    end

    @sync_state.update!(history_id: latest_history_id, last_synced_at: Time.current, last_error: nil)
  rescue Gmail::Client::HistoryExpired
    Gmail::BackfillService.new(@sync_state).perform
    @sync_state.update!(last_recovery_at: Time.current, last_error: nil)
    Gmail::WatchService.new(@sync_state).perform
  rescue StandardError => e
    @sync_state.update_column(:last_error, "#{e.class}: #{e.message}")
    raise
  end

  def self.import_message(sync_state, gmail_message)
    labels = Array(gmail_message['labelIds'])
    return unless labels.include?('INBOX') || (labels.include?('SENT') && sync_state.sync_sent_messages?)

    mail = Mail.read_from_string(Base64.urlsafe_decode64(gmail_message.fetch('raw')))
    if labels.include?('SENT')
      return if chatwoot_generated_message?(mail)

      Gmail::SentMailbox.new.process(mail, sync_state.channel, sync_state.sent_message_user)
    else
      Imap::ImapMailbox.new.process(mail, sync_state.channel)
    end
  end

  def self.chatwoot_generated_message?(mail)
    mail.message_id.to_s.match?(%r{\A<conversation/[a-zA-Z0-9-]+/messages/\d+@})
  end
end
