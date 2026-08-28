# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class ResultPresenterTest < Minitest::Test
  def test_presents_onboarded_public_identity_and_commands
    actor = PrismBot::Domain::HumanActor.new(canonical_id: "0x0sky", role: "owner")

    message = presenter.started(actor)

    assert_includes message, "Публічний ID: 0x0sky"
    assert_includes message, "/start"
    assert_includes message, "/channels"
  end

  def test_presents_channel_capabilities
    message = presenter.channels(
      [
        {
          "id" => "personal-instagram",
          "label" => "Personal Instagram",
          "provider_id" => "meta.instagram",
          "capabilities" => {
            "formats" => %w[post story],
            "text" => true,
            "media_kinds" => %w[image video]
          }
        }
      ]
    )

    assert_includes message, "формати: post, story"
    assert_includes message, "контент: text, image, video"
  end

  def test_presents_safe_hub_request_reference
    error = PrismBot::HubError.new(
      "hub.channel.not_found",
      "private upstream message",
      http_status: 422,
      request_id: "hub-request-1"
    )

    message = presenter.error(error)

    assert_includes message, "hub-request-1"
    refute_includes message, "private upstream message"
  end

  private

  def presenter
    @presenter ||= PrismBot::Channels::Telegram::ResultPresenter.new
  end
end
