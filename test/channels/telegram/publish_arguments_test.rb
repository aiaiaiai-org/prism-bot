# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class PublishArgumentsTest < Minitest::Test
  def test_uses_default_channels
    parser = PrismBot::Channels::Telegram::PublishArguments.new(
      default_channel_ids: ["personal-threads"]
    )

    result = parser.parse("  Привіт із Prism  ")

    assert_equal ["personal-threads"], result.channel_ids
    assert_equal "Привіт із Prism", result.text
  end

  def test_parses_explicit_channels
    parser = PrismBot::Channels::Telegram::PublishArguments.new(default_channel_ids: [])

    result = parser.parse("[personal-threads, personal-instagram] допис")

    assert_equal %w[personal-threads personal-instagram], result.channel_ids
    assert_equal "допис", result.text
  end

  def test_rejects_missing_text
    parser = PrismBot::Channels::Telegram::PublishArguments.new(
      default_channel_ids: ["personal-threads"]
    )

    assert_raises(PrismBot::InputError) { parser.parse(" ") }
  end
end
