# Change

Describe the single externally visible behavior or repository capability.

## Boundaries

- [ ] Telegram-specific behavior stays in `channels/telegram` or its adapter.
- [ ] Shared use cases depend only on focused ports.
- [ ] Provider credentials and behavior remain outside this repository.
- [ ] Hub contract changes are pinned and the client was regenerated.

## Verification

- [ ] Full CI is green.
- [ ] Secret and authorization failure paths are covered.
- [ ] No tokens, webhook bodies, or upstream response bodies are logged.
- [ ] Deployment remains a separate manual action.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
