# Contributing

Changes follow Draft PR → Full CI → green → explicit merge. Deployment is a
separate manual action.

Telegram handlers own Telegram parsing and presentation only. Publication
policy belongs to channel-independent use cases, Hub HTTP belongs to its adapter,
and provider behavior belongs to `prism`. New commands are registered through
the command router rather than added to a central conditional chain.

Run the README verification commands before requesting review. Start from the
latest `master` on a `feature/*` or `fix/*` branch.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
