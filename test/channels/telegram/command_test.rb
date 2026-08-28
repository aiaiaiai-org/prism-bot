# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class CommandTest < Minitest::Test
  def test_parses_bot_qualified_start_with_payload
    command = PrismBot::Channels::Telegram::Command.parse(
      "/start@PrismPersonalBot referral-code"
    )

    assert_equal "start", command.name
    assert_equal "referral-code", command.arguments
    assert command.frozen?
  end

  def test_returns_nil_for_plain_text
    assert_nil PrismBot::Channels::Telegram::Command.parse("hello")
  end
end
