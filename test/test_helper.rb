# © 2026 aiaiaiai · aiaiaiai.org

require "minitest/autorun"
require "rack/lint"
require "rack/mock"
require "stringio"

require_relative "../lib/prism_bot"

module PrismBotTestSupport
  WEBHOOK_SECRET = "test_webhook_secret_with_32_chars_minimum".freeze

  class FakeActorOnboarder
    include PrismBot::Ports::ActorOnboarder

    attr_reader :requests

    def initialize(actor: nil, error: nil)
      @actor = actor || PrismBot::Domain::HumanActor.new(
        canonical_id: "0x0sky",
        role: "owner"
      )
      @error = error
      @requests = []
    end

    def onboard_actor(provider:, provider_scope:, subject_id:)
      @requests << {
        provider: provider,
        provider_scope: provider_scope,
        subject_id: subject_id
      }
      raise @error if @error

      @actor
    end
  end

  class FakeActorResolver
    include PrismBot::Ports::ActorResolver

    attr_reader :requests

    def initialize(actor: nil, denied_subject_ids: [], error: nil)
      @actor = actor || PrismBot::Domain::HumanActor.new(
        canonical_id: "0x0sky",
        role: "owner"
      )
      @denied_subject_ids = denied_subject_ids.map(&:to_s).freeze
      @error = error
      @requests = []
    end

    def resolve_actor(provider:, provider_scope:, subject_id:)
      @requests << {
        provider: provider,
        provider_scope: provider_scope,
        subject_id: subject_id
      }
      raise @error if @error
      return nil if @denied_subject_ids.include?(subject_id)

      @actor
    end
  end

  class FakeBotLifecycle
    include PrismBot::Ports::BotLifecycle

    attr_reader :requests

    def initialize(status: "active", error: nil)
      @state = PrismBot::Domain::BotLifecycleState.new(status: status)
      @error = error
      @requests = []
    end

    def status(**provider_evidence)
      record(:status, provider_evidence)
      @state
    end

    def pause(**provider_evidence)
      record(:pause, provider_evidence)
      @state = PrismBot::Domain::BotLifecycleState.new(status: "paused")
    end

    def resume(**provider_evidence)
      record(:resume, provider_evidence)
      @state = PrismBot::Domain::BotLifecycleState.new(status: "active")
    end

    private

    def record(operation, provider_evidence)
      @requests << provider_evidence.merge(operation: operation)
      raise @error if @error
    end
  end

  class FakeHubGateway
    include PrismBot::Ports::ActorOnboarder
    include PrismBot::Ports::ActorResolver
    include PrismBot::Ports::BotLifecycle
    include PrismBot::Ports::ChannelCatalog
    include PrismBot::Ports::PublicationPublisher

    attr_reader :publications, :idempotency_keys

    def initialize(channels: [], response: nil, actor: nil)
      @channels = channels
      @response = response || {
        "protocol_version" => "prism-execution.v1",
        "request_id" => "request-test-1",
        "status" => "ok",
        "result" => {"type" => "execution", "data" => {"outcomes" => []}}
      }
      @actor = actor || PrismBot::Domain::HumanActor.new(
        canonical_id: "0x0sky",
        role: "owner"
      )
      @lifecycle_state = PrismBot::Domain::BotLifecycleState.new(status: "active")
      @publications = []
      @idempotency_keys = []
    end

    def onboard_actor(**)
      @actor
    end

    def resolve_actor(**)
      @actor
    end

    def status(**)
      @lifecycle_state
    end

    def pause(**)
      @lifecycle_state = PrismBot::Domain::BotLifecycleState.new(status: "paused")
    end

    def resume(**)
      @lifecycle_state = PrismBot::Domain::BotLifecycleState.new(status: "active")
    end

    def list
      @channels
    end

    def publish(publication:, idempotency_key:)
      @publications << publication
      @idempotency_keys << idempotency_key
      @response
    end
  end

  class FakeMessageSender
    include PrismBot::Ports::MessageSender

    attr_reader :messages

    def initialize
      @messages = []
    end

    def send_message(chat_id:, text:, message_thread_id: nil, location_request: nil, ephemeral: nil)
      message = {"chat_id" => chat_id, "text" => text}
      message["message_thread_id"] = message_thread_id if message_thread_id
      message["location_request"] = location_request if location_request
      message["ephemeral"] = ephemeral if ephemeral
      @messages << message
    end
  end

  class FakeEphemeralSender
    include PrismBot::Ports::EphemeralMessageSender
    include PrismBot::Ports::VoiceSender

    attr_reader :sent, :edits, :voices

    def initialize
      @sent = []
      @edits = []
      @voices = []
    end

    def send_ephemeral_message(target:, text:, reply_markup: nil)
      @sent << {target: target, text: text, reply_markup: reply_markup}
      PrismBot::Domain::EphemeralMessageRef.new(
        chat_id: target.chat_id,
        receiver_user_id: target.receiver_user_id,
        ephemeral_message_id: @sent.length
      )
    end

    def edit_ephemeral_message(ref:, text:, reply_markup: nil)
      @edits << {ref: ref, text: text, reply_markup: reply_markup}
      nil
    end

    def send_ephemeral_voice(target:, clip:, caption:)
      @voices << {target: target, clip: clip, caption: caption}
      ref = PrismBot::Domain::EphemeralMessageRef.new(
        chat_id: target.chat_id,
        receiver_user_id: target.receiver_user_id,
        ephemeral_message_id: 900 + @voices.length
      )
      PrismBot::Domain::VoiceReceipt.new(file_id: "voice-file", ephemeral_ref: ref)
    end

    def send_public_voice(chat_id:, clip:, caption:, message_thread_id: nil)
      @voices << {chat_id: chat_id, message_thread_id: message_thread_id, clip: clip, caption: caption}
      PrismBot::Domain::VoiceReceipt.new(file_id: "voice-file", message_id: 700 + @voices.length)
    end
  end

  class FakeChatMemberLookup
    include PrismBot::Ports::ChatMemberLookup

    def initialize(statuses: {}, own: "administrator")
      @statuses = statuses
      @own = own
    end

    def chat_membership(chat_id:, user_id:)
      PrismBot::Domain::ChatMembership.new(
        chat_id: chat_id, user_id: user_id, status: @statuses.fetch(user_id, "member")
      )
    end

    def own_membership(chat_id:)
      PrismBot::Domain::ChatMembership.new(chat_id: chat_id, user_id: 1, status: @own)
    end
  end

  class FakeCallbackAnswerer
    include PrismBot::Ports::CallbackAnswerer

    attr_reader :answered

    def initialize(error: nil)
      @answered = []
      @error = error
    end

    def answer_callback_query(callback_query_id:, text: nil)
      @answered << callback_query_id
      raise @error if @error
    end
  end

  class FakeTransport
    attr_reader :calls

    def initialize(status: 200, body: "{}", headers: {})
      @response = PrismBot::Adapters::NetHttpTransport::Response.new(
        status: status,
        body: body,
        headers: headers
      )
      @calls = []
    end

    def call(**arguments)
      @calls << arguments
      @response
    end
  end

  class RecordingRouter
    attr_reader :updates

    def initialize(error: nil)
      @error = error
      @updates = []
    end

    def call(update)
      @updates << update
      raise @error if @error
    end
  end

  module_function

  # The smallest bytes that look like an Ogg/Opus voice: an Ogg page header and an Opus head.
  def ogg_opus(extra: "")
    "OggS".b + ("\x00" * 24).b + "OpusHead".b + extra.b
  end

  def telegram_update(text: "/help", update_id: 42, chat_id: -1001, user_id: 7)
    PrismBot::Channels::Telegram::Update.new(
      update_id: update_id,
      chat_id: chat_id,
      user_id: user_id,
      text: text
    )
  end

  def publication
    variant = PrismBot::Domain::Publication::Variant.new(
      id: "variant-1",
      locale: "uk-UA",
      voice_profile: "0x0sky.uk_SP",
      format: "post",
      body: PrismBot::Domain::Publication::Body.new(text: "Привіт"),
      provenance: PrismBot::Domain::Publication::Provenance.new(kind: "human")
    )
    PrismBot::Domain::Publication.new(
      dispatch_policy: "require_all_valid",
      variants: [variant],
      targets: [
        PrismBot::Domain::Publication::Target.new(
          id: "target-1",
          channel_id: "personal-threads",
          selection: PrismBot::Domain::Publication::Selection.exact("variant-1")
        )
      ]
    )
  end

  def webhook_app(
    router:,
    sender: FakeMessageSender.new,
    actor_resolver: FakeActorResolver.new,
    actor_onboarder: FakeActorOnboarder.new,
    bot_lifecycle: FakeBotLifecycle.new,
    allowed_chat_ids: [],
    max_body_bytes: 1024,
    callback_answerer: nil,
    observation_parser: nil,
    observer: nil,
    logger: Logger.new(StringIO.new),
    open_commands: []
  )
    lifecycle = PrismBot::Channels::Telegram::LifecycleController.new(
      bot_lifecycle: PrismBot::UseCases::ManageBotLifecycle.new(bot_lifecycle: bot_lifecycle)
    )
    PrismBot::Channels::Telegram::WebhookApp.new(
      secret: PrismBot::Channels::Telegram::WebhookSecret.new(WEBHOOK_SECRET),
      update_parser: PrismBot::Channels::Telegram::UpdateParser.new,
      context_policy: PrismBot::Channels::Telegram::ContextPolicy.new(
        allowed_chat_ids: allowed_chat_ids
      ),
      actor_authorizer: PrismBot::Channels::Telegram::ActorAuthorizer.new(
        resolve_actor: PrismBot::UseCases::ResolveActor.new(
          actor_resolver: actor_resolver
        ),
        onboard_actor: PrismBot::UseCases::OnboardActor.new(
          actor_onboarder: actor_onboarder
        ),
        open_commands: open_commands
      ),
      lifecycle_gate: PrismBot::Channels::Telegram::LifecycleGate.new(lifecycle: lifecycle, open_commands: open_commands),
      command_router: router,
      message_sender: sender,
      presenter: PrismBot::Channels::Telegram::ResultPresenter.new,
      logger: logger,
      max_body_bytes: max_body_bytes,
      callback_answerer: callback_answerer,
      observation_parser: observation_parser,
      observer: observer
    )
  end

  def webhook_environment(payload, secret: WEBHOOK_SECRET)
    Rack::MockRequest.env_for(
      "/telegram/webhook",
      method: "POST",
      input: JSON.generate(payload),
      "CONTENT_TYPE" => "application/json",
      "HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN" => secret
    )
  end

  def ephemeral_command_payload(text: "/whisper", update_id: 42, chat_id: -1001, user_id: 7, ephemeral_message_id: 5, thread: nil)
    message = {
      "chat" => {"id" => chat_id, "type" => "supergroup"},
      "from" => {"id" => user_id},
      "text" => text,
      "message_id" => 0,
      "ephemeral_message_id" => ephemeral_message_id
    }
    message["message_thread_id"] = thread if thread
    {"update_id" => update_id, "message" => message}
  end

  def callback_payload(data: "w:go", id: "cb-1", update_id: 43, chat_id: -1001, user_id: 7, thread: nil, source_ephemeral: nil)
    message = {"message_id" => 99, "date" => 1_700_000_000, "chat" => {"id" => chat_id, "type" => "supergroup"}}
    message["message_thread_id"] = thread if thread
    message.merge!("message_id" => 0, "ephemeral_message_id" => source_ephemeral) if source_ephemeral
    {
      "update_id" => update_id,
      "callback_query" => {"id" => id, "from" => {"id" => user_id, "is_bot" => false}, "data" => data, "message" => message}
    }
  end

  def telegram_payload(text: "/help", update_id: 42, chat_id: -1001, user_id: 7)
    {
      "update_id" => update_id,
      "message" => {
        "chat" => {"id" => chat_id, "type" => "supergroup"},
        "from" => {"id" => user_id},
        "text" => text
      }
    }
  end
end
