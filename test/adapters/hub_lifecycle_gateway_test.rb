# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class HubLifecycleGatewayTest < Minitest::Test
  Client = Struct.new(:response, :calls) do
    def get_personal_bot_status(**arguments)
      calls << [:status, arguments]
      response
    end

    def pause_personal_bot(**arguments)
      calls << [:pause, arguments]
      response
    end

    def resume_personal_bot(**arguments)
      calls << [:resume, arguments]
      response
    end
  end

  def test_maps_minimal_hub_lifecycle_response_to_domain_state
    client = Client.new({"bot_instance" => {"status" => "paused"}}, [])
    gateway = PrismBot::Adapters::HubGateway.new(client: client)

    state = gateway.status(provider: "telegram", provider_scope: "global", subject_id: "7")

    assert state.paused?
    operation, evidence = client.calls.fetch(0)
    assert_equal :status, operation
    assert_equal({provider: "telegram", provider_scope: "global", subject_id: "7"}, evidence)
  end

  def test_rejects_malformed_or_unknown_lifecycle_state
    invalid_responses = [
      {},
      {"bot_instance" => {}},
      {"bot_instance" => {"status" => "unknown"}}
    ]

    invalid_responses.each do |response|
      gateway = PrismBot::Adapters::HubGateway.new(client: Client.new(response, []))
      error = assert_raises(PrismBot::TransportError) do
        gateway.status(provider: "telegram", provider_scope: "global", subject_id: "7")
      end
      assert_equal "bot.hub.lifecycle.response.invalid", error.code
    end
  end
end
