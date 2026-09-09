# Foundation status

## Ready in this repository

- Rack webhook process with `/healthz` and `/telegram/webhook`.
- Telegram secret verification plus Hub-resolved human actor authorization.
- Telegram numeric user IDs adapted to generic `provider=telegram`,
  `provider_scope=global` evidence without making them canonical identities.
- Optional local chat-context restriction that cannot authorize a human by itself.
- Immutable `HumanActor` and `AuthorizedUpdate` values carrying canonical identity
  into interaction handling.
- Explicit `/start` onboarding backed by Hub's idempotent provider identity flow.
- Ordinary commands use read-only personal actor resolution and never create
  identity state as a fallback.
- Hub-owned per-user lifecycle controls: `/status`, `/stop`, `/resume`.
- A central lifecycle gate blocks ordinary commands while `paused` or `disabled`
  without stopping the shared Telegram webhook process.
- `/help`, `/channels`, and multi-channel text `/publish` commands.
- Stable publication idempotency keys based on Telegram update IDs.
- Immutable provider-neutral publication aggregate.
- Public `PrismBot::Client` composition boundary for concrete bot products.
- Frozen safe client services that expose use cases and non-secret defaults without
  exposing Hub/Telegram credentials or adapters.
- Immutable interaction keys, states, and explicit state transitions.
- Injected interaction-state store port with fail-closed stateless default.
- Deterministic routing of ordinary follow-up messages while commands retain
  priority over pending state.
- Default Prism Bot behaviour implemented through the same composition API used
  by external clients.
- Generated Prism Hub v1 client pinned byte-for-byte to Hub `0.1.0-alpha.8`,
  including onboarding, personal actor resolution, and lifecycle operations.
- Bounded channel pagination, capability validation, actor/lifecycle response
  validation, and correlated Hub errors.
- Tests and Full CI gates for syntax, style, behaviour, dependencies,
  architecture, contracts, copyright, and lockfile drift.

## Required before a live personal deployment

- Complete Hub-owned social-account access with Meta OAuth credential connection.
- Merge a concrete `0x0sky/prisma-telegram` client composition against this API.
- Select its hosting environment and configure HTTPS.
- Create a Telegram bot, install secrets, and register its webhook.
- Provision the Hub service principal with actor, lifecycle, and required
  publication capabilities.
- Provide a durable interaction-state store before enabling multi-message flows
  in production.
- Deploy Prism Hub with durable account/channel configuration and idempotency.
- Compose Prism runtime with real provider adapters and secret storage.
- Implement and verify live Threads, Instagram, and Facebook publishing before
  advertising those targets as operational.

This repository intentionally does not claim that Meta publishing is live. It
supplies the multi-user identity, lifecycle, and reusable client-composition
boundaries needed to add concrete clients without coupling them to provider APIs.

## Concrete client boundary

A concrete client such as `0x0sky/prisma-telegram` should pin this gem by an exact
release or commit and call `PrismBot::Bootstrap.build(env: ENV, client: client)`.
It may own product-specific commands, presentation, conversational states, and a
state-store adapter. It must not fork Hub integration, copy provider credentials,
reimplement identity/lifecycle rules, or rely on Telegram username as identity.

## Next executable increment

Consume this composition contract from `0x0sky/prisma-telegram` and implement the
first explicit multi-message product flow: begin a post, persist an
`awaiting_post_content` state, route the next ordinary message as content, and
then hand the resulting publication intent to the existing Prism publishing use
case.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
