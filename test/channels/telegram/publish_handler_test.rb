# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class PublishHandlerTest < Minitest::Test
  include PrismBotTestSupport

  def test_builds_one_provider_neutral_post_for_multiple_hub_channels
    gateway = FakeHubGateway.new
    sender = FakeMessageSender.new
    handler = PrismBot::Channels::Telegram::Handlers::Publish.new(
      arguments_parser: PrismBot::Channels::Telegram::PublishArguments.new(
        default_channel_ids: []
      ),
      publish_publication: PrismBot::UseCases::PublishPublication.new(
        publication_publisher: gateway
      ),
      message_sender: sender,
      presenter: PrismBot::Channels::Telegram::ResultPresenter.new,
      instance_id: "0x0sky-personal",
      locale: "uk-UA",
      voice_profile: "0x0sky.uk_SP",
      dispatch_policy: "require_all_valid"
    )

    handler.call(
      update: telegram_update(text: "/publish ignored", update_id: 42),
      arguments: "[personal-threads,personal-instagram-post] Привіт"
    )

    payload = gateway.publications.fetch(0).to_h
    assert_equal ["post"], payload.fetch("variants").map { _1.fetch("format") }
    assert_equal 2, payload.fetch("targets").length
    assert_equal "telegram:0x0sky-personal:42", gateway.idempotency_keys.fetch(0)
    assert_match(/request-test-1/, sender.messages.fetch(0).fetch("text"))
  end
end
