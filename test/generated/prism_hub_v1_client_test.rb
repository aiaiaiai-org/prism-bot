# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class PrismHubV1ClientTest < Minitest::Test
  include PrismBotTestSupport

  TOKEN = "test_hub_token_with_at_least_32_characters".freeze

  def test_encodes_channel_page_parameters
    transport = FakeTransport.new(
      body: JSON.generate("channels" => [], "page" => {"limit" => 25, "next_cursor" => nil})
    )
    client = build_client(transport)

    client.list_channels(limit: 25, cursor: "next page")

    request = transport.calls.fetch(0)
    assert_equal(
      "https://hub.example.test/api/v1/channels?limit=25&cursor=next+page",
      request.fetch(:url)
    )
  end

  def test_sends_pinned_publication_contract_with_idempotency_key
    transport = FakeTransport.new(
      body: JSON.generate("status" => "ok", "request_id" => "request-1")
    )
    client = build_client(transport, base_url: "https://hub.example.test/")

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
        "request_id" => "hub-request-1",
        "error" => {"code" => "provider_not_found", "message" => "not found"}
      )
    )
    client = build_client(transport)

    error = assert_raises(PrismBot::HubError) do
      client.publish_publication(payload: {"variants" => []}, idempotency_key: "key")
    end

    assert_equal "provider_not_found", error.code
    assert_equal 422, error.http_status
    assert_equal "hub-request-1", error.request_id
  end

  private

  def build_client(transport, base_url: "https://hub.example.test")
    PrismBot::Generated::PrismHubV1Client.new(
      base_url: base_url,
      token: TOKEN,
      transport: transport
    )
  end
end
