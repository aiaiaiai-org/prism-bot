# Changelog

## Unreleased

### Added

- Modular Telegram webhook foundation.
- Generated Prism Hub API client and pinned contract.
- Multi-channel text publication command.
- Paginated Hub channel discovery with capability validation and request correlation.
- Hub-resolved Telegram human actors with canonical identity and workspace role.
- Optional Telegram chat-context restriction separated from human authorization.
- Hub actor onboarding and read-only personal actor client operations.
- Explicit Telegram `/start` onboarding with idempotent Hub-backed identity creation.
- Hub-backed per-user bot lifecycle commands `/status`, `/stop`, and `/resume`.
- Central lifecycle gating that blocks ordinary commands for paused or disabled personal instances.
- Public immutable `PrismBot::Client::Composition` and safe client services for concrete bot products.
- Explicit interaction-state key, state, transition, and state-store contracts for multi-message flows.
- Interaction routing that preserves command priority while deterministically routing ordinary follow-up messages.

### Changed

- Telegram user authorization now resolves through Prism Hub identity bindings;
  the former local user allow-list is rejected at configuration time.
- Existing Telegram actor authorization now uses Hub personal actor resolution,
  so the client no longer needs to know a human workspace before authorization.
- Ordinary Telegram commands never fall back to onboarding when actor resolution
  denies the sender; identity creation remains exclusive to `/start`.
- The pinned Hub contract is now `0.1.0-alpha.8` and includes personal lifecycle operations.
- `/stop` persists a personal pause in Hub and never terminates the shared webhook process.
- `PrismBot::Bootstrap` now composes the default Telegram client through the same
  public client boundary available to external products instead of hardcoding
  handlers and presentation inside bootstrap wiring.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
