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
