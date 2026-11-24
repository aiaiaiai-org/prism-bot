# Architecture

Prism Bot is a modular monolith and reusable bot-client infrastructure. Every
messaging surface is an inbound channel module with its own parsing and
presentation. Channel-independent publication and actor-resolution behaviour
lives in use cases and reaches Prism Hub only through focused ports. Concrete
client products compose these capabilities through the public `PrismBot::Client`
boundary instead of rebuilding infrastructure wiring.

```mermaid
flowchart TD
    Webhook["Telegram webhook"] --> Context["Telegram context policy"]
    Context --> ActorAuth["Telegram actor authorizer"]
    ActorAuth --> ActorUseCase["Resolve or onboard actor use case"]
    ActorUseCase --> ActorPort["Actor resolver / onboarder ports"]
    ActorAdapter["Hub adapter + generated client"] --> ActorPort
    ActorAdapter --> Hub["Prism Hub API v1"]
    ActorAuth --> Interaction["Interaction router"]
    Client["Concrete client composition"] --> Interaction
    Interaction --> Command["Command registry"]
    Interaction --> State["Interaction state handler"]
    StateStore["Injected interaction-state port"] --> Interaction
    Command --> Handler["Telegram handlers"]
    State --> Handler
    Handler --> UseCase["Publication use cases"]
    UseCase --> Port["Focused Hub ports"]
    ActorAdapter --> Port
```

## Responsibilities

| Layer | Owns | Must not own |
|---|---|---|
| `domain` | Immutable publication, actor, interaction-key, state, and transition values | HTTP, Telegram credentials, storage |
| `use_cases` | Channel-independent orchestration | JSON, environment, framework code |
| `ports` | Small capabilities required by use cases and interaction state | Concrete transport or persistence details |
| `channels/telegram` | Telegram parsing, context filtering, provider-subject adaptation, interaction routing, messages | Canonical identity policy, Meta credentials, provider policy |
| `client` | Safe composition services, standard client definition, immutable handler/state composition | Hub adapters, raw credentials, environment parsing |
| `adapters` | Hub HTTP, Telegram Bot API calls, Hub response validation, explicit port implementations | Publication decisions or Telegram identity semantics |
| `bootstrap` | Environment parsing, infrastructure construction, client composition | Runtime product behaviour |

## Client composition contract

`PrismBot::Bootstrap.build` accepts a client object that responds to `call` and
receives a frozen `PrismBot::Client::Services` value. Services expose only the
capabilities a client may legitimately compose: message delivery, channel
listing, publication, bot lifecycle, and non-secret publication defaults. They
do not expose Telegram tokens, Hub credentials, `HubGateway`, HTTP transport, or
provider credentials.

A client returns an immutable `PrismBot::Client::Composition` containing command
handlers, state handlers, a fallback handler, presenter, and an explicit
interaction-state store. `PrismBot::Client::Default` expresses the existing
`/start`, `/help`, `/context`, `/status`, `/stop`, `/resume`, `/channels`, and `/publish`
behaviour using the same public contract. There is no parallel bootstrap path for
the built-in client.

Concrete products can extend that composition without copying infrastructure:

```ruby
base = PrismBot::Client::Default.new.call(services)
base.with(
  command_handlers: {"create_post" => begin_post},
  state_handlers: {"awaiting_post_content" => capture_post},
  state_store: durable_store
)
```

The example objects are product-owned handlers. The store is a port implementation
chosen by the concrete client/deployment. Prism Bot deliberately does not hide a
process-global conversation hash behind the API.

## Interaction state

Stateful conversations use `InteractionKey(instance_id, surface, actor_ref)`.
For Telegram, `actor_ref` comes from the Hub-resolved canonical `HumanActor`, not
Telegram username or chat label. The instance ID prevents two concrete bot
products used by the same person from sharing accidental state. The Telegram
surface includes chat and optional topic IDs; see
[SurfaceContext](telegram-surface-context.md) for state cleanup and migration.

`InteractionState` is immutable and carries a validated state name plus
JSON-compatible data. Handlers request state changes by returning an immutable
`InteractionTransition` (`set`, `clear`, or `keep`). Ordinary handler return
values preserve state, which keeps existing stateless handlers compatible.

Commands have priority over pending ordinary-message state. This means lifecycle
and control commands remain deterministic while a client is waiting for a
follow-up message. An ordinary message is routed to the handler registered for
the current state. A persisted state without a registered handler is a typed,
observable configuration failure rather than an implicit fallback.

The default composition uses a fail-closed null state store. Stateless behaviour
works without persistence; the first attempted `set` transition fails visibly
unless the concrete client supplied an actual store. Production stateful clients
therefore have to make persistence ownership explicit.

## Command registry

The command router remains a registry. Adding a command means supplying another
handler object, not extending a central command or provider conditional. Telegram
command parsing is shared by the router and actor gate so `/start` cannot be
recognized differently at the identity and dispatch boundaries. The interaction
router sits around the command registry only to add explicit follow-up state
routing; it does not reinterpret commands.

## Human and machine identity

Telegram's webhook secret authenticates ingress. It does not authenticate the
human sender. The bot independently authenticates to Hub with its scoped machine
credential, while Telegram actor evidence follows this chain:

```text
Telegram numeric user ID
    -> decimal string at the Telegram adapter boundary
    -> provider=telegram, provider_scope=global
    -> ActorResolver / ActorOnboarder port
    -> Hub ProviderIdentityBinding
    -> Hub UserIdentity
    -> server-derived personal workspace + owner membership
    -> HumanActor(person:<canonical-id>, role)
```

Ordinary actor authorization uses Hub's read-only personal actor resolution. The
client does not supply a workspace identifier and cannot create or reactivate
identity state. Hub derives the personal workspace from the canonical identity
and requires its active owner membership before returning the actor projection.

`/start` is the only Telegram command that selects the separate onboarding use
case. Hub owns idempotent resolve-or-create behaviour, so repeated `/start` calls
return the same canonical identity rather than creating local bot state. A failed
ordinary resolution never falls back to onboarding. This keeps identity creation
explicit and prevents arbitrary commands from becoming account-creation events.

The resulting `AuthorizedUpdate` composes the original immutable Telegram update
with the resolved `HumanActor`. Existing command handlers consume the update
interface while interaction state scopes itself from the canonical actor.

`PRISM_BOT_TELEGRAM_ALLOWED_CHAT_IDS` is only a local context filter. An empty
list means every chat may attempt Hub actor resolution or explicit `/start`
onboarding. A configured list can reject a chat before a network call, but a chat
ID never proves who the human is. The former local Telegram user allow-list is
rejected at configuration time.

Hub's explicit `hub.actor.not_authorized` result is mapped to an ordinary
deny-without-disclosure outcome. Other Hub failures, including missing machine
capabilities, remain typed failures instead of being misreported as an unknown
human. The bot does not notify a sender when actor resolution or onboarding
itself failed, because that sender has not yet been authenticated as a human
actor.

## Delivery and failure semantics

Each `/publish` update produces a stable idempotency key:
`telegram:<instance-id>:<update-id>`. A handled or unexpected downstream failure
after actor authorization is acknowledged to Telegram after at most one user
notification attempt. This prevents the bot from deliberately replaying an
external publication after an ambiguous failure; Hub/runtime remains responsible
for enforcing idempotency at the publication boundary.

The bot never receives provider credentials and targets only public Hub channel
IDs. The generated client is derived from a byte-for-byte pinned OpenAPI file.
The Hub adapter owns cursor traversal and validates every page before channel
metadata crosses the port. It also validates actor responses and exposes only
canonical human identity plus workspace role; provider subject IDs do not enter
command presentation.

## Ephemeral and voice delivery

`PrismBot::Client::Services` exposes two further ports for products that answer only one person
inside a group or topic: `ephemeral_message_sender` (`send_ephemeral_message`,
`edit_ephemeral_message`) and `voice_sender` (`send_ephemeral_voice`, `send_public_voice`). Both
are implemented by `Adapters::Telegram::EphemeralBotApiClient`. This layer is transport only: it
adds no command, collection or product behaviour.

Verified against the [Bot API reference](https://core.telegram.org/bots/api) at version 10.5
(ephemeral messages arrived in 10.2; `EphemeralMessageParameters` in 10.3; callback replies without
`receiver_user_id` in 10.4):

| Use | Telegram API | Notes |
|---|---|---|
| send | `sendMessage` with `ephemeral_message_parameters` | `EphemeralMessageParameters` has `receiver_user_id`, `callback_query_id`, `replace_callback_query_message` |
| edit | `editEphemeralMessageText` | requires `chat_id`, `receiver_user_id`, `ephemeral_message_id`; `text` 1-4096 characters |
| voice | `sendVoice` with `ephemeral_message_parameters` | Ogg/Opus; caption 0-1024 characters; up to 50 MB |
| command | `BotCommand.is_ephemeral` | declared by the bot; not set by this repository |

An ephemeral message is also identified by `Message.ephemeral_message_id` (and `message_id` is `0`)
and carries `Message.receiver_user`. A non-administrator bot may send one only within 15 seconds of
the receiver's action, by answering a `callback_query_id` or replying to an incoming
`reply_parameters.ephemeral_message_id`. An administrator bot may message any non-bot member at any
time. `Domain::EphemeralTarget` records which of the three applies (`reply_to_callback`,
`reply_to_ephemeral`, `to_member`), so a product cannot send without naming its authority.

Rules the adapter enforces:

- **Private or an error.** A success response counts as private delivery only if it carries a
  positive `ephemeral_message_id`, a zero `message_id`, and a `receiver_user` equal to the intended
  receiver. Otherwise it raises `bot.telegram.ephemeral.unconfirmed`. Nothing is ever re-sent
  publicly. Telegram does not guarantee that the receiver sees the message (for example when they
  are offline), so a success is never proof that the person saw it.
- **Never shortened.** Text over 4096 characters or a caption over 1024 raises `InputError`.
- **Native voice only.** `Domain::VoiceClip` accepts Ogg/Opus only, and a result without
  `Message.voice` raises `bot.telegram.voice.unconfirmed`. There is no `sendAudio` or `sendDocument`
  fallback.
- **Private and public voice are different methods.** `send_public_voice` is for an explicit,
  user-confirmed share; a missing target can never turn a private voice public.
- **No content in errors.** Telegram's error text is not copied into exceptions.

Live Telegram verification of the response fields is still required before any deploy.

### Private updates

An incoming update is **private** when it is an ephemeral command or a button press. The parser
marks a message private when it has `ephemeral_message_id`, `receiver_user` or `message_id` `0`;
a marker without a positive `ephemeral_message_id` raises `bot.telegram.ephemeral.invalid` instead
of being read as a public message. (The Bot API reference describes these fields on `Message` but
does not show an incoming ephemeral update, so this reading, and the topic of a press on an
ephemeral message, still need a live check.)

- `Update#reply_target` of a private update carries an `ephemeral:` target (`reply_to_ephemeral`
  for a command, `reply_to_callback` for a press). Every handler already answers with
  `send_message(**update.reply_target, ...)`, so each of them, and the webhook's own error and
  lifecycle notices, now reply privately.
- Handlers receive `Services#message_sender`, a `PrivateReplySender`: no target means a public
  reply, a target means `send_ephemeral_message`. A private reply that fails raises. It is never
  re-sent publicly. The plain `BotApiClient` refuses an `ephemeral:` argument rather than posting it.
- A private update's text is not group content. Products that record group messages must skip
  updates where `private?` is true.
- A button press is a `callback_query` on a message in a group, supergroup or private chat. It is
  routed to `Composition#callback_handlers` by the part of `callback_data` before the first `:`
  (up to 64 bytes; the payload is untrusted). An unregistered route is ignored without output.
  A press never reads or changes pending text state.
- `WebhookApp` answers every press with `answerCallbackQuery` after handling it, also when it was
  refused or failed, so the button's progress bar clears. Answering last keeps `callback_query_id`
  usable for a private reply within Telegram's 15-second window.
- Presses on inline-mode or inaccessible messages, in channels, by bots, or without data are ignored.
- The bot still has to declare a command with `is_ephemeral` (`setMyCommands`) for Telegram to
  deliver it privately; this repository does not register commands.

## Chat membership

`Services#chat_member_lookup` (`Ports::ChatMemberLookup`, implemented by
`Adapters::Telegram::ChatMemberClient`) answers who is in a chat and with what standing through
`getChatMember`: `chat_membership(chat_id:, user_id:)` and `own_membership(chat_id:)`. A
`Domain::ChatMembership` carries one of `creator`, `administrator`, `member`, `restricted`, `left`,
`kicked`; `administrator?` is true for the first two, which is the check a product should use before
letting someone switch a chat feature on.

Telegram guarantees an answer about other people only when this bot is an administrator of the chat.
The adapter accepts a response only if it names the person asked about with a known status; any other
answer, a refusal, or an unreachable Telegram raises `MessageDeliveryError`. A caller must treat that
as "not confirmed", never as an administrator. `own_membership` takes the bot's id from the token
prefix and raises `ConfigurationError` if the token has none.


<!-- © 2026 aiaiaiai · aiaiaiai.org -->
