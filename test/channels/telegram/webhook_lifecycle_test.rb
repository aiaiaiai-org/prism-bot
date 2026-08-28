# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class WebhookLifecycleTest < Minitest::Test
  include PrismBotTestSupport

  def test_paused_personal_instance_blocks_publish_before_router
    router = RecordingRouter.new
    sender = FakeMessageSender.new
    lifecycle = FakeBotLifecycle.new(status: "paused")
    app = webhook_app(router: router, sender: sender, bot_lifecycle: lifecycle)

    status, = app.call(webhook_environment(telegram_payload(text: "/publish hello")))

    assert_equal 200, status
    assert_empty router.updates
    assert_equal :status, lifecycle.requests.fetch(0).fetch(:operation)
    assert_equal 1, sender.messages.length
    assert_match(/paused|призупинен/i, sender.messages.fetch(0).fetch("text"))
  end

  def test_resume_bypasses_gate_and_reaches_command_router
    router = RecordingRouter.new
    lifecycle = FakeBotLifecycle.new(status: "paused")
    app = webhook_app(router: router, bot_lifecycle: lifecycle)

    status, = app.call(webhook_environment(telegram_payload(text: "/resume")))

    assert_equal 200, status
    assert_equal 1, router.updates.length
    assert_empty lifecycle.requests
  end

  def test_help_bypasses_lifecycle_network_lookup
    router = RecordingRouter.new
    lifecycle = FakeBotLifecycle.new(status: "paused")
    app = webhook_app(router: router, bot_lifecycle: lifecycle)

    app.call(webhook_environment(telegram_payload(text: "/help")))

    assert_equal 1, router.updates.length
    assert_empty lifecycle.requests
  end
end
