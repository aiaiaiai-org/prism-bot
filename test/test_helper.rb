# © 2026 aiaiaiai · aiaiaiai.org

require "minitest/autorun"
require "rack/mock"
require "stringio"

require_relative "../lib/prism_bot"

module PrismBotTestSupport
  WEBHOOK_SECRET = "test_webhook_secret_with_32_chars_minimum".freeze

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

  class FakeHubGateway
    include PrismBot::Ports::ActorResolver
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
      @publications = []
      @idempotency_keys = []
    end

    def resolve_actor(provider:, provider_scope:, subject_id:)
      @actor
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

    def send_message(chat_id:, text:)
      @messages << {"chat_id" => chat_id, "text" => text}
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
    allowed_chat_ids: [],
    max_body_bytes: 1024
  )
    logger = Logger.new(StringIO.new)
    PrismBot::Channels::Telegram::WebhookApp.new(
      secret: PrismBot::Channels::Telegram::WebhookSecret.new(WEBHOOK_SECRET),
      update_parser: PrismBot::Channels::Telegram::UpdateParser.new,
      context_policy: PrismBot::Channels::Telegram::ContextPolicy.new(
        allowed_chat_ids: allowed_chat_ids
      ),
      actor_authorizer: PrismBot::Channels::Telegram::ActorAuthorizer.new(
        resolve_actor: PrismBot::UseCases::ResolveActor.new(
          actor_resolver: actor_resolver
        )
      ),
      command_router: router,
      message_sender: sender,
      presenter: PrismBot::Channels::Telegram::ResultPresenter.new,
      logger: logger,
      max_body_bytes: max_body_bytes
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

  def telegram_payload(text: "/help", update_id: 42, chat_id: -1001, user_id: 7)
    {
      "update_id" => update_id,
      "message" => {
        "chat" => {"id" => chat_id},
        "from" => {"id" => user_id},
        "text" => text
      }
    }
  end
end
