class Gmail::BackfillService
  OVERLAP = 2.days

  def initialize(sync_state)
    @sync_state = sync_state
    @client = Gmail::Client.new(sync_state.channel)
  end

  def perform
    history_id = @client.profile.fetch('historyId')
    page_token = nil
    query = "after:#{(Time.current - OVERLAP).to_date.strftime('%Y/%m/%d')}"

    loop do
      page = @client.messages(query: query, page_token: page_token)
      Array(page['messages']).each do |message|
        gmail_message = @client.message(message.fetch('id'))
        Gmail::HistorySyncService.import_message(@sync_state, gmail_message) if gmail_message.present?
      end
      page_token = page['nextPageToken']
      break if page_token.blank?
    end

    history_id
  end
end
