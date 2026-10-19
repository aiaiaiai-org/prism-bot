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

  def test_binds_a_telegram_chat_and_omits_unset_optional_fields
    transport = FakeTransport.new(body: JSON.generate("binding" => {"status" => "active"}))

    build_client(transport).bind_telegram_surface(
      workspace_id: "personal-0x0sky",
      logical_channel: "notifications",
      chat_id: 42,
      provider: "telegram",
      provider_scope: "global",
      subject_id: "123456789"
    )

    request = transport.calls.fetch(0)
    assert_equal "https://hub.example.test/api/v1/telegram/surfaces/bind", request.fetch(:url)
    assert_equal(
      {
        "provider" => "telegram",
        "provider_scope" => "global",
        "subject_id" => "123456789",
        "workspace_id" => "personal-0x0sky",
        "logical_channel" => "notifications",
        "chat_id" => 42
      },
      JSON.parse(request.fetch(:body))
    )
  end

  def test_personal_call_reaches_only_operations_the_contract_declares
    transport = FakeTransport.new(body: JSON.generate("ok" => true))
    client = build_client(transport)
    path = PrismBot::Generated::PrismHubV1Client::POST_PATHS.fetch(0)

    client.personal_call(
      path: path,
      provider: "telegram",
      provider_scope: "global",
      subject_id: "7",
      fields: {"anything" => 1}
    )

    request = transport.calls.fetch(0)
    assert_equal "https://hub.example.test#{path}", request.fetch(:url)
    assert_equal(
      {"provider" => "telegram", "provider_scope" => "global", "subject_id" => "7", "anything" => 1},
      JSON.parse(request.fetch(:body))
    )

    ["/api/v1/not-in-the-contract", "https://evil.test/", "/api/v1/channels"].each do |unknown|
      error = assert_raises(PrismBot::InputError) do
        client.personal_call(path: unknown, provider: "telegram", provider_scope: "global", subject_id: "7")
      end
      assert_equal "bot.hub.operation.unknown", error.code
    end
    assert_equal 1, transport.calls.length
  end

  private

  def build_client(transport)
    PrismBot::Generated::PrismHubV1Client.new(
      base_url: "https://hub.example.test",
      token: TOKEN,
      transport: transport
    )
  end
end
