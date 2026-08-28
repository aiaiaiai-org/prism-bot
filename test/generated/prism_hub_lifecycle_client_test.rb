# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class PrismHubLifecycleClientTest < Minitest::Test
  include PrismBotTestSupport

  TOKEN = "test_hub_token_with_at_least_32_characters".freeze

  def test_sends_provider_evidence_to_each_lifecycle_operation
    operations = {
      get_personal_bot_status: "/api/v1/bot-instances/personal/status",
      pause_personal_bot: "/api/v1/bot-instances/personal/pause",
      resume_personal_bot: "/api/v1/bot-instances/personal/resume"
    }

    operations.each do |method, path|
      transport = FakeTransport.new(body: JSON.generate("bot_instance" => {"status" => "active"}))
      client = PrismBot::Generated::PrismHubV1Client.new(
        base_url: "https://hub.example.test",
        token: TOKEN,
        transport: transport
      )

      client.public_send(
        method,
        provider: "telegram",
        provider_scope: "global",
        subject_id: "123456789"
      )

      request = transport.calls.fetch(0)
      assert_equal "POST", request.fetch(:method)
      assert_equal "https://hub.example.test#{path}", request.fetch(:url)
      refute request.fetch(:headers).key?("idempotency-key")
      assert_equal(
        {
          "provider" => "telegram",
          "provider_scope" => "global",
          "subject_id" => "123456789"
        },
        JSON.parse(request.fetch(:body))
      )
    end
  end
end
