# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class WebhookAppTest < Minitest::Test
  include PrismBotTestSupport

  def test_rejects_invalid_webhook_secret
    router = RecordingRouter.new
    app = webhook_app(router: router)

    status, = app.call(webhook_environment(telegram_payload, secret: "wrong"))

    assert_equal 401, status
    assert_empty router.updates
  end

  def test_acknowledges_unauthorized_actor_without_dispatching
    router = RecordingRouter.new
    app = webhook_app(router: router)

    status, = app.call(webhook_environment(telegram_payload(user_id: 999)))

    assert_equal 200, status
    assert_empty router.updates
  end

  def test_dispatches_authorized_text_update
    router = RecordingRouter.new
    app = webhook_app(router: router)

    status, = app.call(webhook_environment(telegram_payload(text: "/channels")))

    assert_equal 200, status
    assert_equal "/channels", router.updates.fetch(0).text
  end

  def test_acknowledges_handler_error_and_does_not_retry_publication
    sender = FakeMessageSender.new
    error = PrismBot::HubError.new(
      "provider_not_found",
      "private upstream details",
      http_status: 422
    )
    router = RecordingRouter.new(error: error)
    app = webhook_app(router: router, sender: sender)

    status, = app.call(webhook_environment(telegram_payload(text: "/publish hello")))

    assert_equal 200, status
    assert_equal 1, router.updates.length
    assert_equal 1, sender.messages.length
    refute_includes sender.messages.fetch(0).fetch("text"), "private upstream details"
  end

  def test_rejects_oversized_body_before_parsing
    router = RecordingRouter.new
    app = webhook_app(router: router, max_body_bytes: 8)

    status, = app.call(webhook_environment(telegram_payload))

    assert_equal 413, status
    assert_empty router.updates
  end

  def test_health_check_requires_no_secret
    app = webhook_app(router: RecordingRouter.new)
    environment = Rack::MockRequest.env_for("/healthz", method: "GET")

    status, = app.call(environment)

    assert_equal 200, status
  end
end
