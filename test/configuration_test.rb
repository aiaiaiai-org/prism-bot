# © 2026 aiaiaiai · aiaiaiai.org

require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def test_parses_chat_context_and_secure_defaults
    configuration = PrismBot::Configuration.new(
      "PRISM_BOT_INSTANCE_ID" => "personal-bot",
      "PRISM_BOT_TELEGRAM_TOKEN" => "telegram-token",
      "PRISM_BOT_TELEGRAM_WEBHOOK_SECRET" => "a" * 32,
      "PRISM_BOT_TELEGRAM_ALLOWED_CHAT_IDS" => "[-1001]",
      "PRISM_BOT_DEFAULT_CHANNEL_IDS" => '["personal-threads"]',
      "PRISM_HUB_BASE_URL" => "https://hub.example.test",
      "PRISM_HUB_API_TOKEN" => "b" * 32
    )

    assert_equal [-1001], configuration.allowed_chat_ids
    assert_equal ["personal-threads"], configuration.default_channel_ids
    refute configuration.allow_insecure_http
  end

  def test_rejects_legacy_local_user_authorization_configuration
    environment = base_environment.merge(
      "PRISM_BOT_TELEGRAM_ALLOWED_USER_IDS" => "[7]"
    )

    error = assert_raises(PrismBot::ConfigurationError) do
      PrismBot::Configuration.new(environment)
    end

    assert_equal "bot.configuration.telegram_user_allowlist.deprecated", error.code
  end

  def test_rejects_invalid_chat_context_json
    environment = base_environment.merge(
      "PRISM_BOT_TELEGRAM_ALLOWED_CHAT_IDS" => "not-json"
    )

    assert_raises(PrismBot::ConfigurationError) do
      PrismBot::Configuration.new(environment)
    end
  end

  private

  def base_environment
    {
      "PRISM_BOT_INSTANCE_ID" => "personal-bot",
      "PRISM_BOT_TELEGRAM_TOKEN" => "telegram-token",
      "PRISM_BOT_TELEGRAM_WEBHOOK_SECRET" => "a" * 32,
      "PRISM_HUB_BASE_URL" => "https://hub.example.test",
      "PRISM_HUB_API_TOKEN" => "b" * 32
    }
  end
end
