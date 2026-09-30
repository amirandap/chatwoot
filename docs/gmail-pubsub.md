# Gmail Pub/Sub native inboxes

This fork can replace IMAP polling for a native Google `Channel::Email` inbox. It keeps Chatwoot's RFC822/MIME importer, so email HTML, regular attachments, inline images and reply threading follow the native email path.

## Required configuration

Set these environment variables on both Rails and Sidekiq:

- `GMAIL_PUBSUB_TOPIC`: full Google topic name, e.g. `projects/<project>/topics/<topic>`.
- `GMAIL_PUBSUB_AUDIENCE`: exact audience configured on the Pub/Sub push subscription.
- `GMAIL_PUBSUB_SERVICE_ACCOUNT`: service-account email used by that push subscription.

The subscription must push to `POST /webhooks/gmail/pubsub` with an OIDC token. The endpoint verifies issuer, audience, expiration, service-account email, signature and Google certificate key id before it accepts a notification.

Grant Gmail's publishing service account `gmail-api-push@system.gserviceaccount.com` the Publisher role on the configured topic.

## Enable an inbox

Create or reconnect the inbox as a native Google email inbox first, then run:

```sh
bundle exec rails 'gmail_pubsub:enable[mailbox@example.com]'
```

To mirror emails written in Gmail's **Sent** folder into Chatwoot as outgoing messages, supply the responsible Chatwoot user ID:

```sh
bundle exec rails 'gmail_pubsub:enable[mailbox@example.com,42]'
```

This explicit mapping prevents a Gmail-composed reply from being attributed to an arbitrary agent. Chatwoot-originated replies are already sent with Gmail OAuth SMTP and are deduplicated by RFC `Message-ID`.

## Recovery and operations

The daily watch-renewal job preserves the existing `historyId`; it never advances the cursor. Every Pub/Sub notification enqueues a per-inbox locked History API job. The job writes the new cursor only after every returned MIME message was imported successfully. A too-old history cursor causes a two-day, idempotent reconciliation, then consumes History API from the cursor captured before that reconciliation, and finally renews the watch.

The IMAP polling scheduler skips only an active state with an unexpired watch, while `imap_enabled` remains true so native Gmail OAuth sending continues to work. If a watch expires before it can renew, IMAP automatically resumes as a fail-safe.
