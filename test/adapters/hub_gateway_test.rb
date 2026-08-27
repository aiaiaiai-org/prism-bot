# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class HubGatewayTest < Minitest::Test
  class PagedClient
    attr_reader :calls

    def initialize(responses)
      @responses = responses
      @calls = []
    end

    def list_channels(limit:, cursor:)
      @calls << {limit: limit, cursor: cursor}
      @responses.fetch(@calls.length - 1)
    end
  end

  class ActorClient
    attr_reader :calls

    def initialize(response: nil, error: nil)
      @response = response
      @error = error
      @calls = []
    end

    def resolve_actor(provider:, provider_scope:, subject_id:)
      @calls << {
        provider: provider,
        provider_scope: provider_scope,
        subject_id: subject_id
      }
      raise @error if @error

      @response
    end
  end

  def test_maps_hub_actor_response_to_provider_independent_human_actor
    client = ActorClient.new(
      response: {
        "actor" => {
          "identity" => {"type" => "person", "id" => "0x0sky"},
          "role" => "owner"
        }
      }
    )
    gateway = PrismBot::Adapters::HubGateway.new(client: client)

    actor = gateway.resolve_actor(
      provider: "telegram",
      provider_scope: "global",
      subject_id: "123456789"
    )

    assert_equal "person:0x0sky", actor.canonical_ref
    assert_equal "owner", actor.role
    assert_equal(
      [{provider: "telegram", provider_scope: "global", subject_id: "123456789"}],
      client.calls
    )
  end

  def test_collapses_only_hub_actor_not_authorized_to_nil
    client = ActorClient.new(
      error: PrismBot::HubError.new(
        "hub.actor.not_authorized",
        "actor is not authorized",
        http_status: 403
      )
    )
    gateway = PrismBot::Adapters::HubGateway.new(client: client)

    assert_nil gateway.resolve_actor(
      provider: "telegram",
      provider_scope: "global",
      subject_id: "999"
    )
  end

  def test_propagates_machine_capability_denial
    error = PrismBot::HubError.new(
      "hub.authorization.capability_denied",
      "principal lacks actors:resolve",
      http_status: 403
    )
    gateway = PrismBot::Adapters::HubGateway.new(
      client: ActorClient.new(error: error)
    )

    raised = assert_raises(PrismBot::HubError) do
      gateway.resolve_actor(
        provider: "telegram",
        provider_scope: "global",
        subject_id: "7"
      )
    end

    assert_same error, raised
  end

  def test_rejects_malformed_actor_disclosure
    gateway = PrismBot::Adapters::HubGateway.new(
      client: ActorClient.new(
        response: {
          "actor" => {
            "identity" => {"type" => "service", "id" => "telegram-bot"},
            "role" => "owner"
          }
        }
      )
    )

    error = assert_raises(PrismBot::TransportError) do
      gateway.resolve_actor(
        provider: "telegram",
        provider_scope: "global",
        subject_id: "7"
      )
    end

    assert_equal "bot.hub.actor.identity_type.invalid", error.code
  end

  def test_collects_all_channel_pages
    client = PagedClient.new(
      [response("one", "cursor-1"), response("two", nil)]
    )
    gateway = PrismBot::Adapters::HubGateway.new(client: client)

    channels = gateway.list

    assert_equal %w[one two], channels.map { |channel| channel.fetch("id") }
    assert_equal [{limit: 100, cursor: nil}, {limit: 100, cursor: "cursor-1"}], client.calls
    assert channels.frozen?
  end

  def test_rejects_a_repeated_cursor
    client = PagedClient.new(
      [response("one", "same"), response("two", "same")]
    )

    error = assert_raises(PrismBot::TransportError) do
      PrismBot::Adapters::HubGateway.new(client: client).list
    end

    assert_equal "bot.hub.channels.cursor_repeated", error.code
  end

  def test_rejects_a_duplicate_channel_across_pages
    client = PagedClient.new(
      [response("same", "next"), response("same", nil)]
    )

    error = assert_raises(PrismBot::TransportError) do
      PrismBot::Adapters::HubGateway.new(client: client).list
    end

    assert_equal "bot.hub.channels.duplicate", error.code
  end

  private

  def response(id, next_cursor)
    {
      "channels" => [
        {
          "id" => id,
          "label" => id.capitalize,
          "provider_id" => "meta.threads",
          "capabilities" => {
            "formats" => ["post"],
            "text" => true,
            "media_kinds" => []
          }
        }
      ],
      "page" => {"limit" => 100, "next_cursor" => next_cursor}
    }
  end
end
