# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class CallbackRoutingTest < Minitest::Test
  include PrismBotTestSupport

  Telegram = PrismBot::Channels::Telegram

  def update(data)
    Telegram::UpdateParser.new.call(callback_payload(data: data))
  end

  def test_routes_by_the_data_prefix_and_passes_the_rest_as_arguments
    seen = []
    router = Telegram::CallbackRouter.new(handlers: {"W" => ->(update:, arguments:) { seen << [update.callback.id, arguments] }})

    router.call(update("w:share:3"))

    assert_equal [["cb-1", "share:3"]], seen
  end

  def test_an_unknown_route_is_ignored_without_output
    router = Telegram::CallbackRouter.new(handlers: {"w" => ->(**) { flunk "must not run" }})

    assert_nil router.call(update("other:1"))
    assert_nil Telegram::CallbackRouter.new.call(update("w:1"))
  end

  def test_a_press_never_reads_pending_text_state
    store = Object.new
    def store.load(**) = raise("a press must not touch state")
    seen = []
    interaction = Telegram::InteractionRouter.new(
      command_router: ->(_update) { flunk "a press is not a command" },
      state_handlers: {},
      state_store: store,
      instance_id: "bot",
      callback_router: Telegram::CallbackRouter.new(handlers: {"w" => ->(update:, arguments:) { seen << arguments }})
    )

    interaction.call(authorized(update("w:go")))

    assert_equal ["go"], seen
  end

  def test_composition_collects_and_merges_callback_handlers
    handler = ->(**) { }
    base = PrismBot::Client::Composition.new(
      command_handlers: {}, fallback: ->(**) { }, presenter: PrismBot::Channels::Telegram::ResultPresenter.new,
      callback_handlers: {"W" => handler}
    )
    merged = base.with(callback_handlers: {"x" => handler})

    assert_equal %w[w], base.callback_handlers.keys
    assert_equal %w[w x], merged.callback_handlers.keys.sort
    assert_raises(ArgumentError) { base.with(callback_handlers: {"y" => 1}) }
  end

  private

  def authorized(update)
    Telegram::AuthorizedUpdate.new(
      update: update, actor: PrismBot::Domain::HumanActor.new(canonical_id: "0x0sky", role: "owner")
    )
  end
end
