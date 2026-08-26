# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class PrismHubV1ClientTest < Minitest::Test
  include PrismBotTestSupport

  TOKEN = "test_hub_token_with_at_least_32_characters".freeze

  def test_sends_pinned_publication_contract_with_idempotency_key
    transport = FakeTransport.new(
      body: JSON.generate("status" => "ok", "request_id" => "request-1")
    )
    client = PrismBot::Generated::PrismHubV1Client.new(
      base_url: "https://hub.example.test/",
      token: TOKEN,
      transport: transport
    )

    client.publish_publication(payload: {"variants" => []}, idempotency_key: "telegram:test:1")

    request = transport.calls.fetch(0)
    assert_equal "https://hub.example.test/api/v1/publications", request.fetch(:url)
    assert_equal "telegram:test:1", request.fetch(:headers).fetch("idempotency-key")
    assert_equal "Bearer #{TOKEN}", request.fetch(:headers).fetch("authorization")
  end

  def test_converts_non_success_response_to_typed_hub_error
    transport = FakeTransport.new(
      status: 422,
      body: JSON.generate(
        "status" => "error",
        "error" => {"code" => "provider_not_found", "message" => "not found"}
      )
    )
    client = PrismBot::Generated::PrismHubV1Client.new(
      base_url: "https://hub.example.test",
      token: TOKEN,
      transport: transport
    )

    error = assert_raises(PrismBot::HubError) do
      client.publish_publication(payload: {"variants" => []}, idempotency_key: "key")
    end

    assert_equal "provider_not_found", error.code
    assert_equal 422, error.http_status
  end
end
