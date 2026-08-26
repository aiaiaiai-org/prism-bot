# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class CommandRouterTest < Minitest::Test
  include PrismBotTestSupport

  class RecordingHandler
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(**arguments)
      @calls << arguments
    end
  end

  def test_routes_bot_qualified_command_without_a_type_switch
    publish = RecordingHandler.new
    fallback = RecordingHandler.new
    router = PrismBot::Channels::Telegram::CommandRouter.new(
      handlers: {"publish" => publish},
      fallback: fallback
    )
    update = telegram_update(text: "/publish@PrismPersonalBot hello")

    router.call(update)

    assert_equal "hello", publish.calls.fetch(0).fetch(:arguments)
    assert_empty fallback.calls
  end

  def test_delegates_unknown_text_to_fallback
    fallback = RecordingHandler.new
    router = PrismBot::Channels::Telegram::CommandRouter.new(
      handlers: {},
      fallback: fallback
    )

    router.call(telegram_update(text: "not a command"))

    assert_equal 1, fallback.calls.length
  end
end
