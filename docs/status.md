# Foundation status

## Ready in this repository

- Rack webhook process with `/healthz` and `/telegram/webhook`.
- Telegram secret verification and deny-by-default actor authorization.
- `/help`, `/channels`, and multi-channel text `/publish` commands.
- Stable publication idempotency keys based on Telegram update IDs.
- Immutable provider-neutral publication aggregate.
- Generated Prism Hub v1 client pinned to an exact source commit and SHA-256.
- Tests and Full CI gates for syntax, style, behavior, dependencies,
  architecture, contracts, copyright, and lockfile drift.

## Required before a live personal deployment

- Create the private or public `0x0sky/prisma-telegram` composition repository.
- Select its hosting environment and configure HTTPS.
- Create a Telegram bot, install secrets, and register its webhook.
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
Hub schema, or store Meta credentials.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
