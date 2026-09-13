# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class ClientCompositionTest < Minitest::Test
  include PrismBotTestSupport

  class MemoryStateStore
    include PrismBot::Ports::InteractionStateStore

    def initialize
      @states = {}
    end

    def load(key:)
      @states[key]
    end

    def store(key:, state:)
      @states[key] = state
    end

    def delete(key:)
      @states.delete(key)
    end
  end

  class BeginPost
    def initialize(sender:)
      @sender = sender
    end

    def call(update:, arguments:)
      @sender.send_message(chat_id: update.chat_id, text: "send post content")
      PrismBot::Domain::InteractionTransition.set(
        PrismBot::Domain::InteractionState.new(
          name: "awaiting_post_content",
          data: {"source" => arguments}
        )
      )
    end
  end

  class CapturePost
    attr_reader :texts

    def initialize
      @texts = []
    end

    def call(update:, state:)
      @texts << [update.text, state.data.fetch("source")]
      PrismBot::Domain::InteractionTransition.clear
    end
  end

  def test_concrete_client_adds_two_message_flow_without_rebuilding_infrastructure
    sender = FakeMessageSender.new
    services = client_services(sender)
    store = MemoryStateStore.new
    capture = CapturePost.new
    base = PrismBot::Client::Default.new.call(services)
    composition = base.with(
      command_handlers: {"create_post" => BeginPost.new(sender: sender)},
      state_handlers: {"awaiting_post_content" => capture},
      state_store: store
    )
    router = interaction_router(composition, services)

    router.call(authorized_update(text: "/create_post manual"))
    router.call(authorized_update(text: "/help", update_id: 43))
    router.call(authorized_update(text: "hello from follow-up", update_id: 44))

    assert_equal [["hello from follow-up", "manual"]], capture.texts
    assert_equal "send post content", sender.messages.fetch(0).fetch("text")
    assert sender.messages.any? { _1.fetch("text").include?("/publish") }
    assert_nil store.load(key: interaction_key(services))
  end

  def test_services_do_not_expose_transport_credentials
    services = client_services(FakeMessageSender.new)

    refute_respond_to services, :telegram_token
    refute_respond_to services, :hub_api_token
    refute_respond_to services, :hub_gateway
  end

  def test_pending_interaction_is_isolated_by_chat_topic_and_actor
    sender = FakeMessageSender.new
    services = client_services(sender)
    store = MemoryStateStore.new
    capture = CapturePost.new
    composition = PrismBot::Client::Default.new.call(services).with(
      command_handlers: {"create_post" => BeginPost.new(sender: sender)},
      state_handlers: {"awaiting_post_content" => capture},
      state_store: store
    )
    router = interaction_router(composition, services)

    router.call(scoped_update(text: "/create_post topic-13"))
    router.call(scoped_update(text: "other topic", thread_id: 14))
    router.call(scoped_update(text: "other chat", chat_id: -2002))
    router.call(scoped_update(text: "chat root", thread_id: nil))
    router.call(scoped_update(text: "other actor", actor_id: "someone-else"))
    router.call(scoped_update(text: "/context"))
    assert_empty capture.texts

    router.call(scoped_update(text: "correct topic"))
    assert_equal [["correct topic", "topic-13"]], capture.texts
    router.call(scoped_update(text: "state already cleared"))
    assert_equal 1, capture.texts.length
  end

  def test_start_includes_context_card_and_targets_same_topic
    sender = FakeMessageSender.new
    services = client_services(sender)
    composition = PrismBot::Client::Default.new.call(services)

    interaction_router(composition, services).call(scoped_update(text: "/start"))

    message = sender.messages.fetch(0)
    assert_equal 13, message.fetch("message_thread_id")
    assert_includes message.fetch("text"), "Topic ID: 13"
    assert_includes message.fetch("text"), "Публічний ID: 0x0sky"
  end

  private

  def scoped_update(text:, chat_id: -1001, thread_id: 13, actor_id: "0x0sky")
    surface = PrismBot::Channels::Telegram::SurfaceContext.new(
      chat_id: chat_id, chat_type: "supergroup", message_thread_id: thread_id
    )
    PrismBot::Channels::Telegram::AuthorizedUpdate.new(
      update: PrismBot::Channels::Telegram::Update.new(
        update_id: 42, chat_id: chat_id, user_id: 7, text: text, surface_context: surface
      ),
      actor: PrismBot::Domain::HumanActor.new(canonical_id: actor_id, role: "owner")
    )
  end

  def client_services(sender)
    PrismBot::Client::Services.new(
      instance_id: "test-client",
      default_channel_ids: ["personal-threads"],
      default_locale: "uk-UA",
      default_voice_profile: "0x0sky.uk_SP",
      dispatch_policy: "require_all_valid",
      message_sender: sender,
      list_channels: ->(**) { [] },
      publish_publication: ->(**) { {} },
      bot_lifecycle: FakeBotLifecycle.new
    )
  end

  def interaction_router(composition, services)
    PrismBot::Channels::Telegram::InteractionRouter.new(
      command_router: PrismBot::Channels::Telegram::CommandRouter.new(
        handlers: composition.command_handlers,
        fallback: composition.fallback
      ),
      state_handlers: composition.state_handlers,
      state_store: composition.state_store,
      instance_id: services.instance_id
    )
  end

  def authorized_update(text:, update_id: 42)
    PrismBot::Channels::Telegram::AuthorizedUpdate.new(
      update: telegram_update(text: text, update_id: update_id),
      actor: PrismBot::Domain::HumanActor.new(canonical_id: "0x0sky", role: "owner")
    )
  end

  def interaction_key(services)
    PrismBot::Domain::InteractionKey.new(
      instance_id: services.instance_id,
      surface: "telegram:-1001:root",
      actor_ref: "person:0x0sky"
    )
  end
end
