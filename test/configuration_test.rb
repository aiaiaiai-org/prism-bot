# © 2026 aiaiaiai · aiaiaiai.org

require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def test_parses_json_lists_and_secure_defaults
    configuration = PrismBot::Configuration.new(
      "PRISM_BOT_INSTANCE_ID" => "personal-bot",
      "PRISM_BOT_TELEGRAM_TOKEN" => "telegram-token",
      "PRISM_BOT_TELEGRAM_WEBHOOK_SECRET" => "a" * 32,
      "PRISM_BOT_TELEGRAM_ALLOWED_USER_IDS" => "[7]",
      "PRISM_BOT_DEFAULT_CHANNEL_IDS" => '["personal-threads"]',
      "PRISM_HUB_BASE_URL" => "https://hub.example.test",
      "PRISM_HUB_API_TOKEN" => "b" * 32
    )

    assert_equal [7], configuration.allowed_user_ids
    assert_equal ["personal-threads"], configuration.default_channel_ids
    refute configuration.allow_insecure_http
  end

  def test_rejects_invalid_json_configuration
    environment = {
      "PRISM_BOT_INSTANCE_ID" => "personal-bot",
      "PRISM_BOT_TELEGRAM_TOKEN" => "telegram-token",
      "PRISM_BOT_TELEGRAM_WEBHOOK_SECRET" => "a" * 32,
      "PRISM_BOT_TELEGRAM_ALLOWED_USER_IDS" => "not-json",
      "PRISM_HUB_BASE_URL" => "https://hub.example.test",
      "PRISM_HUB_API_TOKEN" => "b" * 32
    }

    assert_raises(PrismBot::ConfigurationError) { PrismBot::Configuration.new(environment) }
  end
end
