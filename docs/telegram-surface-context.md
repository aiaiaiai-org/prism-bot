# Telegram SurfaceContext and Context Card

`PrismBot::Channels::Telegram::SurfaceContext` is an immutable Telegram delivery address and display context. It is not a human identity or a Hub context binding.

| Field | Contract |
| --- | --- |
| `chat_id` | Nonzero Telegram integer ID |
| `chat_type` | `private`, `group`, `supergroup`, `channel`; `unknown` only for older direct `Update` constructors |
| `message_thread_id` | Optional positive integer for a supergroup or private-chat topic |
| `title` | Optional display-only chat title; never used as an identity or state key |
| `kind` | `forum_topic` when a topic ID exists, otherwise the chat type |
| `reply_target` | `chat_id` and, only when present, `message_thread_id` |

The parser preserves this context from text `message` and `channel_post` updates. Edited updates, non-text updates, membership events, and topic creation/rename service messages do not initiate an interaction. Topic titles are not guessed from ordinary messages; the Context Card shows the topic ID when a title is unavailable.

`AuthorizedUpdate` delegates `surface_context` and `reply_target` without changing the Hub-resolved human actor. A channel post, a message sent on behalf of a chat (`sender_chat`), or a bot sender never supplies human identity evidence. Channel management is currently unsupported. After webhook and chat-allowlist checks, `/start` and `/context` in a channel receive only this static notice, with no Hub identity lookup or command execution:

> Керування Prism у каналі поки не підтримується. Відкрий особистий чат із ботом або гілку групи.

Other channel posts are acknowledged without a reply. Existing outbound channel delivery remains available independently of interactive channel management.

## Context Card

The shared composition adds `/context`; `/start` prepends the same card to onboarding copy. Both remain subject to existing actor authorization and lifecycle gates in interactive chats. The card shows Prism, the chat title or surface label, surface type, chat ID, optional topic ID, and `Прив’язка Hub: не перевірена`. Rendering is bounded plain text; chat titles cannot inject new lines or Telegram markup.

The card deliberately does not claim that a Hub binding exists. Binding creation, binding authorization, persisted topic metadata, Porter routing, and module activation need their own Hub/Porter contracts; this slice neither creates local substitutes nor calls an invented Hub API.

## Reply and state integration

All shared command responses, lifecycle notices, and handled-error replies use the incoming `reply_target`. The message sender accepts optional `message_thread_id`; omitting it preserves the existing root-chat payload and truncation behaviour.

Client-owned handlers must also forward the target:

```ruby
message_sender.send_message(**update.reply_target, text: text)
```

Interaction state is keyed by client instance, `telegram:<chat_id>:<topic_id-or-root>`, and Hub-resolved actor reference. Pending content in one topic cannot be consumed by another topic, another chat, or another actor. Commands retain priority over pending content.

This is an intentional state-scope change from the former provider-only `telegram` key. Existing pending interactions must be restarted after adopting this dependency. There is no fallback to old keys because it would reintroduce cross-chat state leakage. The state-store port and on-disk document format do not change.

Consumers such as `prism-hubot` must update their immutable dependency pin and their client-owned reply handlers before using topic interactions. Existing client test doubles need the optional sender keyword for topic tests. This PR does not modify a consumer pin or deploy any application.

Telegram field semantics: [Message](https://core.telegram.org/bots/api#message), [sendMessage](https://core.telegram.org/bots/api#sendmessage).

<!-- © 2026 aiaiaiai · aiaiaiai.org -->
