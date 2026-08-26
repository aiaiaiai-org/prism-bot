# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class HubChannelPageTest < Minitest::Test
  def test_builds_an_immutable_page
    page = PrismBot::Adapters::HubChannelPage.new(response(next_cursor: "next-page"))

    assert_equal "personal-threads", page.channels.fetch(0).fetch("id")
    assert_equal ["post"], page.channels.fetch(0).dig("capabilities", "formats")
    assert_equal "next-page", page.next_cursor
    assert page.frozen?
    assert page.channels.frozen?
  end

  def test_rejects_missing_capabilities
    value = response(next_cursor: nil)
    value.fetch("channels").first.delete("capabilities")

    error = assert_raises(PrismBot::TransportError) do
      PrismBot::Adapters::HubChannelPage.new(value)
    end

    assert_equal "bot.hub.channels.invalid", error.code
  end

  private

  def response(next_cursor:)
    {
      "channels" => [
        {
          "id" => "personal-threads",
          "label" => "Personal Threads",
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
