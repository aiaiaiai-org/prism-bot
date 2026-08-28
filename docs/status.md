# Foundation status

## Ready in this repository

- Rack webhook process with `/healthz` and `/telegram/webhook`.
- Telegram secret verification plus Hub-resolved human actor authorization.
- Telegram numeric user IDs adapted to generic `provider=telegram`,
  `provider_scope=global` evidence without making them canonical identities.
- Optional local chat-context restriction that cannot authorize a human by itself.
- Immutable `HumanActor` and `AuthorizedUpdate` values carrying canonical identity
  into command handling.
- Explicit `/start` onboarding backed by Hub's idempotent provider identity flow.
- Ordinary commands use read-only personal actor resolution and never create
  identity state as a fallback.
- Hub-owned per-user lifecycle controls: `/status`, `/stop`, `/resume`.
- A central lifecycle gate blocks ordinary commands while `paused` or `disabled`
  without stopping the shared Telegram webhook process.
- `/help`, `/channels`, and multi-channel text `/publish` commands.
- Stable publication idempotency keys based on Telegram update IDs.
- Immutable provider-neutral publication aggregate.
- Generated Prism Hub v1 client pinned byte-for-byte to Hub `0.1.0-alpha.8`,
  including onboarding, personal actor resolution, and lifecycle operations.
- Bounded channel pagination, capability validation, actor/lifecycle response
  validation, and correlated Hub errors.
- Tests and Full CI gates for syntax, style, behavior, dependencies,
  architecture, contracts, copyright, and lockfile drift.

## Required before a live personal deployment

- Add Hub-owned social-account access and Meta OAuth connection state.
- Create and populate the `0x0sky/prisma-telegram` composition repository.
- Select its hosting environment and configure HTTPS.
- Create a Telegram bot, install secrets, and register its webhook.
- Provision the Hub service principal with actor, lifecycle, and required
  publication capabilities.
- Deploy Prism Hub with durable account/channel configuration and idempotency.
- Compose Prism runtime with real provider adapters and secret storage.
- Implement and verify live Threads, Instagram, and Facebook publishing before
  advertising those targets as operational.

This repository intentionally does not claim that Meta publishing is live. It
supplies the multi-user identity and lifecycle client boundary needed to add
social-account authorization without coupling Telegram to Meta APIs.

## Thin personal composition

The future `0x0sky/prisma-telegram` repository should pin this gem by an exact
release or commit, provide environment/deployment files, and run
`PrismBot::Bootstrap.build(env: ENV)`. It should not fork command logic, copy the
Hub schema, store Meta credentials, or maintain a second Telegram-user identity
allow-list.

## Next executable increment

Add the Prism Hub social-account boundary: stable external account identities,
per-user account access, server-side OAuth credential ownership, and explicit
channel bindings for Threads, Instagram, and Facebook. Meta credentials must
never enter Telegram updates or Prism Bot configuration.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
