class Gmail::SentMailbox < Imap::ImapMailbox
  def process(mail, channel, sender)
    raise ArgumentError, 'A Chatwoot user is required to import Gmail Sent messages' if sender.blank?

    @outgoing_sender = sender
    super(mail, channel)
  end

  private

  def incoming_email_from_valid_email?
    true
  end

  def find_or_create_contact
    recipient = sanitize_mailbox_value(@processed_mail.to.first)
    @contact = @inbox.contacts.from_email(recipient)
    @contact_inbox = ContactInbox.find_by(inbox: @inbox, contact: @contact) if @contact.present?
    return if @contact.present?

    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: recipient,
      inbox: @inbox,
      contact_attributes: { name: recipient.split('@').first, email: recipient }
    ).perform
    @contact = @contact_inbox.contact
  end

  def create_message
    source_id = sanitize_mailbox_value(processed_mail.message_id)
    return if @conversation.messages.find_by(source_id: source_id).present?

    @message = @conversation.messages.create!(
      sanitized_message_attributes(source_id).merge(message_type: 'outgoing', sender: @outgoing_sender)
    )
  end
end
