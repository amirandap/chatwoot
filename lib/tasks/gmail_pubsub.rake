namespace :gmail_pubsub do
  desc 'Enable Gmail Pub/Sub for a native Google email inbox: EMAIL[,SENT_USER_ID]'
  task :enable, %i[email sent_user_id] => :environment do |_task, args|
    channel = Channel::Email.find_by!(email: args.fetch(:email))
    raise 'The email channel must use provider google' unless channel.google?

    state = GmailPubsubSyncState.find_or_initialize_by(channel: channel)
    state.email_address = channel.email
    state.sync_sent_messages = args[:sent_user_id].present?
    state.sent_message_user_id = args[:sent_user_id]
    state.save!
    Gmail::WatchService.new(state).perform
    puts "Gmail Pub/Sub enabled for #{channel.email}"
  end
end
