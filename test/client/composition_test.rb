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

  private

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
      surface: "telegram",
      actor_ref: "person:0x0sky"
    )
  end
end
