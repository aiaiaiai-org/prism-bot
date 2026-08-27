# Foundation status

## Ready in this repository

- Rack webhook process with `/healthz` and `/telegram/webhook`.
- Telegram secret verification plus Hub-resolved human actor authorization.
- Telegram numeric user IDs adapted to generic `provider=telegram`,
  `provider_scope=global` evidence without making them canonical identities.
- Optional local chat-context restriction that cannot authorize a human by itself.
- Immutable `HumanActor` and `AuthorizedUpdate` values carrying canonical identity
  and active workspace role into command handling.
- `/help`, `/channels`, and multi-channel text `/publish` commands.
- Stable publication idempotency keys based on Telegram update IDs.
- Immutable provider-neutral publication aggregate.
- Generated Prism Hub v1 client pinned to the exact actor-resolution API source
  commit and SHA-256.
- Bounded channel pagination, capability validation, actor-response validation,
  and correlated Hub errors.
- Tests and Full CI gates for syntax, style, behavior, dependencies,
  architecture, contracts, copyright, and lockfile drift.

## Required before a live personal deployment

- Create and populate the `0x0sky/prisma-telegram` composition repository.
- Select its hosting environment and configure HTTPS.
- Create a Telegram bot, install secrets, and register its webhook.
- Provision the Hub service principal with `actors:resolve` and required command
  capabilities, then provision the personal `UserIdentity`, Telegram binding,
  and active workspace membership.
- Deploy Prism Hub with durable account/channel configuration and idempotency.
- Compose Prism runtime with real provider adapters and secret storage.
- Implement Prism Instagram post/story plus media-resolution capability before
  advertising those targets as live.
- Complete the live Threads adapter composition; the current Prism runtime root
  does not register it.

This repository intentionally does not claim that Instagram or live Threads
publishing is operational. It supplies the client boundary needed to begin that
integration without coupling a personal bot to provider APIs.

## Thin personal composition

The future `0x0sky/prisma-telegram` repository should pin this gem by an exact
release or commit, provide environment/deployment files, and run
`PrismBot::Bootstrap.build(env: ENV)`. It should not fork command logic, copy the
Hub schema, store Meta credentials, or maintain a second Telegram-user identity
allow-list.

## Next executable increment

Add persistent Hub-owned bot lifecycle state (`active`, `paused`, `disabled`),
then expose the focused operations needed by Telegram `/stop`, `/resume`, and
`/status`. Pausing must be durable and must not terminate the webhook process.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
