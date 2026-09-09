# © 2026 aiaiaiai · aiaiaiai.org

require_relative "test_helper"

class BootstrapTest < Minitest::Test
  class CapturingClient
    attr_reader :services

    def call(services)
      @services = services
      PrismBot::Client::Default.new.call(services)
    end
  end

  def test_default_client_still_builds_the_rack_application
    app = PrismBot::Bootstrap.build(env: environment, logger: Logger.new(StringIO.new))
    response = Rack::MockRequest.new(app).get("/healthz")

    assert_equal 200, response.status
    assert_equal "prism-bot", JSON.parse(response.body).fetch("service")
  end

  def test_custom_client_receives_only_safe_composition_services
    client = CapturingClient.new

    PrismBot::Bootstrap.build(
      env: environment,
      client: client,
      logger: Logger.new(StringIO.new)
    )

    assert_equal "test-client", client.services.instance_id
    refute_respond_to client.services, :telegram_token
    refute_respond_to client.services, :hub_api_token
    refute_respond_to client.services, :hub_gateway
  end

  private

  def environment
    {
      "PRISM_BOT_INSTANCE_ID" => "test-client",
      "PRISM_BOT_TELEGRAM_TOKEN" => "telegram-test-token",
      "PRISM_BOT_TELEGRAM_WEBHOOK_SECRET" => "w" * 32,
      "PRISM_BOT_TELEGRAM_ALLOWED_CHAT_IDS" => "[]",
      "PRISM_BOT_DEFAULT_CHANNEL_IDS" => "[]",
      "PRISM_BOT_DEFAULT_LOCALE" => "uk-UA",
      "PRISM_BOT_DEFAULT_VOICE_PROFILE" => "0x0sky.uk_SP",
      "PRISM_BOT_DISPATCH_POLICY" => "require_all_valid",
      "PRISM_HUB_BASE_URL" => "https://hub.example.test",
      "PRISM_HUB_API_TOKEN" => "h" * 32,
      "PRISM_BOT_MAX_WEBHOOK_BYTES" => "1048576",
      "PRISM_BOT_ALLOW_INSECURE_HTTP" => "false"
    }
  end
end
