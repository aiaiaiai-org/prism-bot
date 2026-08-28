# Telegram bot lifecycle

Prism Bot treats lifecycle as Hub-owned per-user state, not as local process state.

A physical Telegram webhook process may serve many human workspaces. `/stop` therefore pauses only the authenticated human's logical `BotInstance`; it never terminates the process or changes another user's lifecycle state. `/resume` reverses a normal pause. `disabled` is a stronger administrative or security state and cannot be cleared through the ordinary user-controlled resume operation.

The Telegram adapter sends only immutable numeric user ID evidence as `provider=telegram`, `provider_scope=global`, `subject_id=<decimal user id>`. Prism Hub derives both the authenticated machine principal and personal workspace server-side.

A central lifecycle gate protects ordinary command dispatch. `/start`, `/help`, `/status`, `/stop`, and `/resume` remain reachable while paused so a user can inspect or recover their own state. Other commands are blocked before their handler runs.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
