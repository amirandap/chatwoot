class CreateGmailPubsubSyncStates < ActiveRecord::Migration[7.1]
  def change
    create_table :gmail_pubsub_sync_states do |t|
      t.references :channel, null: false, foreign_key: { to_table: :channel_email }, index: { unique: true }
      t.string :email_address, null: false
      t.string :history_id
      t.datetime :watch_expires_at
      t.datetime :last_synced_at
      t.datetime :last_recovery_at
      t.text :last_error
      t.bigint :sent_message_user_id
      t.boolean :sync_sent_messages, null: false, default: false
      t.timestamps
    end

    add_index :gmail_pubsub_sync_states, :email_address, unique: true
  end
end
