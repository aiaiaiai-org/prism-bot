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

### Changed

- Telegram user authorization now resolves through Prism Hub identity bindings;
  the former local user allow-list is rejected at configuration time.
- Existing Telegram actor authorization now uses Hub personal actor resolution,
  so the client no longer needs to know a human workspace before authorization.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
