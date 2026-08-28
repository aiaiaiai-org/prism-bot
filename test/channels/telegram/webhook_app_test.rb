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

  def test_acknowledges_context_denial_without_touching_human_identity
    router = RecordingRouter.new
    resolver = FakeActorResolver.new
    onboarder = FakeActorOnboarder.new
    app = webhook_app(
      router: router,
      actor_resolver: resolver,
      actor_onboarder: onboarder,
      allowed_chat_ids: [-2002]
    )

    status, = app.call(webhook_environment(telegram_payload(chat_id: -1001)))

    assert_equal 200, status
    assert_empty resolver.requests
    assert_empty onboarder.requests
    assert_empty router.updates
  end

  def test_acknowledges_unauthorized_ordinary_actor_without_onboarding
    router = RecordingRouter.new
    resolver = FakeActorResolver.new(denied_subject_ids: [999])
    onboarder = FakeActorOnboarder.new
    app = webhook_app(
      router: router,
      actor_resolver: resolver,
      actor_onboarder: onboarder
    )

    status, = app.call(
      webhook_environment(telegram_payload(text: "/help", user_id: 999))
    )

    assert_equal 200, status
    assert_equal "999", resolver.requests.fetch(0).fetch(:subject_id)
    assert_empty onboarder.requests
    assert_empty router.updates
  end

  def test_start_onboards_before_dispatch_even_when_read_only_resolution_would_deny
    router = RecordingRouter.new
    resolver = FakeActorResolver.new(denied_subject_ids: [999])
    onboarder = FakeActorOnboarder.new
    app = webhook_app(
      router: router,
      actor_resolver: resolver,
      actor_onboarder: onboarder
    )

    status, = app.call(
      webhook_environment(telegram_payload(text: "/start", user_id: 999))
    )

    assert_equal 200, status
    assert_empty resolver.requests
    assert_equal "999", onboarder.requests.fetch(0).fetch(:subject_id)
    assert_equal 1, router.updates.length
    assert_equal "person:0x0sky", router.updates.fetch(0).actor.canonical_ref
  end

  def test_dispatches_authorized_update_with_canonical_actor
    router = RecordingRouter.new
    app = webhook_app(router: router)

    status, = app.call(webhook_environment(telegram_payload(text: "/channels")))

    assert_equal 200, status
    authorized = router.updates.fetch(0)
    assert_instance_of PrismBot::Channels::Telegram::AuthorizedUpdate, authorized
    assert_equal "/channels", authorized.text
    assert_equal "person:0x0sky", authorized.actor.canonical_ref
    assert_equal "owner", authorized.actor.role
  end

  def test_does_not_message_an_unverified_actor_when_resolution_fails
    sender = FakeMessageSender.new
    resolver = FakeActorResolver.new(
      error: PrismBot::HubError.new(
        "hub.authorization.capability_denied",
        "machine principal is misconfigured",
        http_status: 403
      )
    )
    router = RecordingRouter.new
    app = webhook_app(router: router, sender: sender, actor_resolver: resolver)

    status, = app.call(webhook_environment(telegram_payload))

    assert_equal 200, status
    assert_empty router.updates
    assert_empty sender.messages
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
