# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class HubAlertGatewayTest < Minitest::Test
  EVIDENCE = {provider: "telegram", provider_scope: "global", subject_id: "7"}.freeze
  CELL = "861e0d9a7ffffff".freeze

  Client = Struct.new(:responses, :calls) do
    def get_personal_alert_subscription(**arguments)
      calls << [:get, arguments]
      responses.fetch(:alert)
    end

    def save_personal_alert_subscription(**arguments)
      calls << [:save, arguments]
      responses.fetch(:alert)
    end

    def clear_personal_alert_subscription(**arguments)
      calls << [:clear, arguments]
      {"alert_subscription" => nil}
    end

    def resolve_personal_actor(**arguments)
      calls << [:resolve, arguments]
      responses.fetch(:actor)
    end

    def get_personal_bot_status(**arguments)
      calls << [:bot_status, arguments]
      {"bot_instance" => {"status" => "active"}}
    end

    def bind_telegram_surface(**arguments)
      calls << [:bind, arguments]
      {"binding" => {"status" => "active"}}
    end
  end

  def test_reads_a_subscription_into_a_domain_value
    client = client_with(alert: alert_response)

    subscription = gateway(client).alert_status(**EVIDENCE)

    assert_equal CELL, subscription.cell
    assert_equal %w[drone missile], subscription.categories
    assert subscription.include_nearby?
    assert_equal [[:get, EVIDENCE]], client.calls
  end

  def test_reads_no_subscription_as_nil
    client = client_with(alert: {"alert_subscription" => nil})

    assert_nil gateway(client).alert_status(**EVIDENCE)
  end

  def test_saves_the_subscription_as_a_cell_and_never_a_position
    client = client_with(alert: alert_response)
    subscription = PrismBot::Domain::AlertSubscription.new(
      cell: CELL,
      categories: %w[drone missile],
      include_nearby: true
    )

    saved = gateway(client).save_alert(**EVIDENCE, subscription: subscription)

    assert_equal subscription.to_h, saved.to_h
    operation, arguments = client.calls.fetch(0)
    assert_equal :save, operation
    assert_equal(
      EVIDENCE.merge(cell: CELL, categories: %w[drone missile], include_nearby: true),
      arguments
    )
  end

  def test_clears_the_subscription
    client = client_with(alert: alert_response)

    assert_nil gateway(client).clear_alert(**EVIDENCE)
    assert_equal [[:clear, EVIDENCE]], client.calls
  end

  def test_binds_a_chat_inside_the_callers_own_workspace
    client = client_with(actor: {"actor" => {"workspace_id" => "personal-0x0sky"}})

    result = gateway(client).bind_surface(**EVIDENCE, logical_channel: "alerts", chat_id: 42)

    assert_nil result
    assert_equal %i[resolve bot_status bind], client.calls.map(&:first)
    assert_equal(
      EVIDENCE.merge(
        workspace_id: "personal-0x0sky",
        logical_channel: "alerts",
        chat_id: 42,
        message_thread_id: nil
      ),
      client.calls.fetch(2).last
    )
  end

  def test_does_not_bind_without_a_personal_workspace
    client = client_with(actor: {"actor" => {"workspace_id" => ""}})

    error = assert_raises(PrismBot::TransportError) do
      gateway(client).bind_surface(**EVIDENCE, logical_channel: "alerts", chat_id: 42)
    end

    assert_equal "bot.hub.actor.workspace.invalid", error.code
    assert_equal [:resolve], client.calls.map(&:first)
  end

  def test_rejects_a_malformed_subscription_response
    [
      {},
      {"alert_subscription" => {}},
      {"alert_subscription" => {"cell" => "nope", "categories" => ["drone"], "include_nearby" => true}},
      {"alert_subscription" => {"cell" => CELL, "categories" => [], "include_nearby" => true}},
      {"alert_subscription" => {"cell" => CELL, "categories" => ["drone"], "include_nearby" => "yes"}}
    ].each do |response|
      error = assert_raises(PrismBot::TransportError) do
        gateway(client_with(alert: response)).alert_status(**EVIDENCE)
      end
      assert_equal "bot.hub.alerts.response.invalid", error.code
    end
  end

  private

  def client_with(**responses)
    Client.new(responses, [])
  end

  def gateway(client)
    PrismBot::Adapters::HubGateway.new(client: client)
  end

  def alert_response
    {
      "alert_subscription" => {
        "cell" => CELL,
        "categories" => %w[drone missile],
        "include_nearby" => true
      }
    }
  end
end
