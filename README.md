# Prism Bot

Prism Bot is the messaging-surface boundary for Prism. The first executable
module is a Telegram webhook application that consumes the versioned Prism Hub
API and never calls Prism, Meta, or another publication provider directly.

This foundation provides:

- a reusable Ruby gem and Rack application;
- a generated, pinned Prism Hub `v1` client;
- Hub-resolved human identity for Telegram actors;
- optional local Telegram chat-context restriction that never substitutes for
  human identity authorization;
- bounded traversal of Hub channel pages with validated publishing capabilities;
- verified Telegram webhook ingress and a focused Bot API sender adapter;
- extensible command routing with `/help`, `/channels`, and text-only
  `/publish` handlers;
- channel-independent publication use cases and immutable domain values;
- Full CI with tests, dependency audit, generated-client drift, architecture,
  and copyright gates.

## Boundary

```mermaid
flowchart TD
    Telegram["Telegram webhook"] --> Context["Optional chat context policy"]
    Context --> Actor["Telegram actor authorizer"]
    Actor --> Resolve["Actor resolver port"]
    Resolve --> HubAdapter["Generated Hub client adapter"]
    HubAdapter --> Hub["prism-hub API v1"]
    Actor --> Commands["Telegram command modules"]
    Commands --> UseCases["Channel-independent use cases"]
    UseCases --> Ports["Channel catalog / publication ports"]
    HubAdapter --> Ports
```

The bot holds only a Hub API token and its Telegram bot token. Provider
credentials remain in Hub/runtime infrastructure. A new messaging surface adds
its own adapter and command modules; it does not add a provider branch to shared
application policy.

Telegram numeric user IDs are converted to opaque provider-subject strings only
at the Telegram adapter boundary. Prism Hub resolves that evidence into a
canonical `UserIdentity` and active workspace membership. Usernames and chat IDs
are never treated as proof of human identity.

## Commands

- `/help` or `/start` — show the supported command syntax;
- `/channels` — list configured channels and their declared formats/content;
- `/publish text` — publish a text post to configured default channels;
- `/publish [channel-a,channel-b] text` — select explicit Hub channel IDs.

The initial Telegram handler creates a `post` variant only. Story/media input is
not simulated: `prism` does not yet provide the media/Instagram adapter required
for live Instagram stories or posts. The pinned Hub contract already models
multi-variant `post` and `story` requests so a personal client can build its UX
against a stable boundary without claiming provider readiness.

## Configuration

Set every value from `.env.example` in the process environment. The Hub service
principal used by this bot must have the `actors:resolve` capability in addition
to whatever channel/publication capabilities its commands require.

Human authorization is Hub-owned. `PRISM_BOT_TELEGRAM_ALLOWED_CHAT_IDS` is an
optional JSON array that restricts where the bot may be used; an empty array
allows any chat context to proceed to Hub actor resolution. It never authorizes
a Telegram user. The removed `PRISM_BOT_TELEGRAM_ALLOWED_USER_IDS` setting is
rejected at boot so an obsolete local allow-list cannot be mistaken for identity
authorization.

Both the Telegram webhook secret and Hub API token must contain at least 32
characters. `PRISM_BOT_DEFAULT_CHANNEL_IDS` is a JSON array of public Hub channel
IDs. `PRISM_BOT_DISPATCH_POLICY` is either `require_all_valid` (default) or
`independent`.

Run the webhook application with:

```bash
bundle install
bundle exec puma -C config/puma.rb
```

Register `/telegram/webhook` with Telegram and set the same secret as
`PRISM_BOT_TELEGRAM_WEBHOOK_SECRET` through Telegram's `secret_token` setting.

## Verification

```bash
bundle exec rubocop
bundle exec rake test
bundle exec bundle-audit check --update
bundle exec rake check
```

The Hub contract is pinned in `contracts/prism-hub.v1.source.yaml`. Generated
code is never edited by hand; `script/generate_hub_client --check` proves drift.
The adapter follows opaque Hub cursors with a fixed page limit, rejects repeated
cursors or malformed capabilities, and retains Hub `request_id` values on typed
errors without exposing upstream private messages. Actor responses are reduced
to canonical human identity plus workspace role; provider subject IDs never
cross into command presentation.

The normative ecosystem rules live in Prism's
[`engineering-principles.md`](https://github.com/aiaiaiai-org/prism/blob/master/docs/engineering-principles.md).

No public software license has been selected for this repository yet.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
