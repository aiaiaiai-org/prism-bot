# Security policy

Report vulnerabilities privately to `security@aiaiaiai.org`.

Never place Telegram tokens, webhook secrets, Hub tokens, provider credentials,
real webhook payloads, provider subject IDs, or provider response bodies in
source, logs, tests, issues, or pull requests. Telegram ingress is rejected
unless its configured secret matches.

Human actor authorization is Hub-owned and remains deny-by-default. A Telegram
chat ID may restrict execution context but never authenticates the human sender;
Telegram numeric user IDs are sent to Hub only as opaque provider evidence.
Unknown or revoked actors are acknowledged without command dispatch and without
identity disclosure. Failures that happen before human actor resolution do not
trigger a message back to the unverified sender.

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
