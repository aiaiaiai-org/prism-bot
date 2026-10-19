# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class HubSurfaceGatewayTest < Minitest::Test
  EVIDENCE = {provider: "telegram", provider_scope: "global", subject_id: "7"}.freeze

  Client = Struct.new(:actor, :calls) do
    def resolve_personal_actor(**arguments)
      calls << [:resolve, arguments]
      actor
    end

    def get_personal_bot_status(**arguments)
      calls << [:bot_status, arguments]
      {"bot_instance" => {"status" => "active"}}
    end

    def bind_telegram_surface(**arguments)
      calls << [:bind, arguments]
      {"binding" => {"status" => "active"}}
    end

    def personal_call(**arguments)
      calls << [:personal, arguments]
      {"ok" => true}
    end
  end

  def test_binds_a_chat_inside_the_callers_own_workspace
    client = Client.new({"actor" => {"workspace_id" => "personal-0x0sky"}}, [])

    result = gateway(client).bind_surface(**EVIDENCE, logical_channel: "notifications", chat_id: 42)

    assert_nil result
    assert_equal %i[resolve bot_status bind], client.calls.map(&:first)
    assert_equal(
      EVIDENCE.merge(
        workspace_id: "personal-0x0sky",
        logical_channel: "notifications",
        chat_id: 42,
        message_thread_id: nil
      ),
      client.calls.fetch(2).last
    )
  end

  def test_does_not_bind_without_a_personal_workspace
    [{"actor" => {"workspace_id" => ""}}, {}, {"actor" => {}}].each do |actor|
      client = Client.new(actor, [])

      error = assert_raises(PrismBot::TransportError) do
        gateway(client).bind_surface(**EVIDENCE, logical_channel: "notifications", chat_id: 42)
      end

      assert_equal "bot.hub.actor.workspace.invalid", error.code
      assert_equal [:resolve], client.calls.map(&:first)
    end
  end

  def test_passes_a_products_own_call_through_unread
    client = Client.new(nil, [])

    response = gateway(client).personal_call(path: "/x", **EVIDENCE, fields: {"a" => 1})

    assert_equal({"ok" => true}, response)
    assert_equal [[:personal, EVIDENCE.merge(path: "/x", fields: {"a" => 1})]], client.calls
  end

  private

  def gateway(client)
    PrismBot::Adapters::HubGateway.new(client: client)
  end
end
