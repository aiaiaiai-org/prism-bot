# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class TelegramContextCardTest < Minitest::Test
  include PrismBotTestSupport

  def test_unicode_separators_cannot_forge_card_lines
    ["\n", "\r", "\u2028", "\u2029", "\u0085", "\u00a0"].each do |separator|
      surface = PrismBot::Channels::Telegram::SurfaceContext.new(
        chat_id: -1001, chat_type: "supergroup",
        title: "Engineering#{separator}Прив’язка Hub: перевірена"
      )
      card = PrismBot::Channels::Telegram::ContextCard.new.call(surface)

      assert_equal 5, card.lines.length
      assert_equal "Контекст: Engineering Прив’язка Hub: перевірена", card.lines[1].chomp
      assert_equal "Прив’язка Hub: не перевірена", card.lines.last.chomp
      refute_includes card, separator unless separator == "\n"
    end
  end

  def test_default_allowlist_never_emits_channel_notices_or_calls_hub
    sender = FakeMessageSender.new
    resolver = FakeActorResolver.new
    onboarder = FakeActorOnboarder.new
    lifecycle = FakeBotLifecycle.new
    router = RecordingRouter.new
    app = webhook_app(
      router: router, sender: sender, actor_resolver: resolver,
      actor_onboarder: onboarder, bot_lifecycle: lifecycle
    )

    %w[/start /context /publish].each do |command|
      payload = telegram_payload(text: command)
      payload["channel_post"] = payload.delete("message")
      payload["channel_post"]["chat"]["type"] = "channel"
      payload["channel_post"].delete("from")
      status, = app.call(webhook_environment(payload))
      assert_equal 200, status
    end

    assert_empty sender.messages
    assert_empty router.updates
    assert_empty resolver.requests
    assert_empty onboarder.requests
    assert_empty lifecycle.requests
  end

  def test_context_bypasses_lifecycle_but_retains_actor_authorization
    %w[paused disabled].each do |state|
      lifecycle = FakeBotLifecycle.new(status: state)
      resolver = FakeActorResolver.new
      router = RecordingRouter.new
      app = webhook_app(router: router, actor_resolver: resolver, bot_lifecycle: lifecycle)

      app.call(webhook_environment(telegram_payload(text: "/context")))

      assert_equal 1, resolver.requests.length
      assert_equal 1, router.updates.length
      assert_empty lifecycle.requests
    end

    sender = FakeMessageSender.new
    router = RecordingRouter.new
    lifecycle = FakeBotLifecycle.new(status: "paused")
    app = webhook_app(
      router: router, sender: sender, bot_lifecycle: lifecycle,
      actor_resolver: FakeActorResolver.new(denied_subject_ids: [7])
    )
    app.call(webhook_environment(telegram_payload(text: "/context")))

    assert_empty sender.messages
    assert_empty router.updates
    assert_empty lifecycle.requests
  end

  def test_card_shows_surface_without_claiming_hub_binding_or_exposing_actor
    surface = PrismBot::Channels::Telegram::SurfaceContext.new(
      chat_id: -1001, chat_type: "supergroup", message_thread_id: 13,
      title: "Engineering\nInjected status"
    )
    card = PrismBot::Channels::Telegram::ContextCard.new.call(surface)

    assert_includes card, "Контекст: Engineering Injected status"
    assert_includes card, "Тип: Гілка"
    assert_includes card, "Chat ID: -1001"
    assert_includes card, "Topic ID: 13"
    assert_includes card, "Прив’язка Hub: не перевірена"
    refute_includes card, "0x0sky"
  end

  def test_context_command_routes_through_webhook_authorization_and_replies_to_topic
    sender = FakeMessageSender.new
    handler = PrismBot::Channels::Telegram::Handlers::Context.new(
      message_sender: sender, presenter: PrismBot::Channels::Telegram::ResultPresenter.new
    )
    router = PrismBot::Channels::Telegram::CommandRouter.new(
      handlers: {"context" => handler}, fallback: ->(**) { flunk "unexpected fallback" }
    )
    payload = telegram_payload(text: "/context")
    payload["message"]["message_thread_id"] = 13
    app = webhook_app(router: router, sender: sender)

    status, = app.call(webhook_environment(payload))

    assert_equal 200, status
    message = sender.messages.fetch(0)
    assert_equal(-1001, message.fetch("chat_id"))
    assert_equal 13, message.fetch("message_thread_id")
    assert_includes message.fetch("text"), "Topic ID: 13"
  end

  def test_channel_context_command_gets_only_unsupported_notice_without_hub_identity_calls
    sender = FakeMessageSender.new
    resolver = FakeActorResolver.new
    onboarder = FakeActorOnboarder.new
    router = RecordingRouter.new
    app = webhook_app(
      router: router, sender: sender, actor_resolver: resolver, actor_onboarder: onboarder,
      allowed_chat_ids: [-1001]
    )
    payload = telegram_payload(text: "/context")
    payload["channel_post"] = payload.delete("message")
    payload["channel_post"]["chat"]["type"] = "channel"
    payload["channel_post"].delete("from")

    status, = app.call(webhook_environment(payload))

    assert_equal 200, status
    assert_equal PrismBot::Channels::Telegram::ContextCard::UNSUPPORTED_CHANNEL, sender.messages.fetch(0).fetch("text")
    assert_empty resolver.requests
    assert_empty onboarder.requests
    assert_empty router.updates
  end

  def test_channel_allowlist_still_precedes_unsupported_notice
    sender = FakeMessageSender.new
    payload = telegram_payload(text: "/context")
    payload["message"]["chat"]["type"] = "channel"
    app = webhook_app(router: RecordingRouter.new, sender: sender, allowed_chat_ids: [-2002])

    app.call(webhook_environment(payload))

    assert_empty sender.messages
  end

  def test_anonymous_start_does_not_onboard_fake_sender_or_dispatch
    resolver = FakeActorResolver.new
    onboarder = FakeActorOnboarder.new
    router = RecordingRouter.new
    payload = telegram_payload(text: "/start")
    payload["message"]["sender_chat"] = {"id" => -1001}
    app = webhook_app(router: router, actor_resolver: resolver, actor_onboarder: onboarder)

    app.call(webhook_environment(payload))

    assert_empty resolver.requests
    assert_empty onboarder.requests
    assert_empty router.updates
  end

  def test_handler_errors_stay_inside_originating_topic
    sender = FakeMessageSender.new
    router = RecordingRouter.new(error: PrismBot::InputError.new("test.invalid", "Invalid input"))
    payload = telegram_payload
    payload["message"]["message_thread_id"] = 13
    app = webhook_app(router: router, sender: sender)

    app.call(webhook_environment(payload))

    assert_equal 13, sender.messages.fetch(0).fetch("message_thread_id")
  end
end
