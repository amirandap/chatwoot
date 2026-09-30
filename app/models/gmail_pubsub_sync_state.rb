class GmailPubsubSyncState < ApplicationRecord
  belongs_to :channel, class_name: 'Channel::Email'
  belongs_to :sent_message_user, class_name: 'User', optional: true

  validates :email_address, presence: true, uniqueness: true
  validates :channel_id, uniqueness: true
  validates :sent_message_user, presence: true, if: :sync_sent_messages?

  scope :active, -> { where(active: true) }
end
