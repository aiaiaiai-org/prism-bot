# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class WebhookPrivateTest < Minitest::Test
  include PrismBotTestSupport

  def setup
    @public = FakeMessageSender.new
    @private = FakeEphemeralSender.new
    @sender = PrismBot::Adapters::Telegram::PrivateReplySender.new(public_sender: @public, ephemeral_sender: @private)
    @answerer = FakeCallbackAnswerer.new
  end

  def post(payload, router: RecordingRouter.new, sender: @sender, **options)
    app = webhook_app(router: router, sender: sender, callback_answerer: @answerer, **options)
    status, = app.call(webhook_environment(payload))
    status
  end

  def test_an_ephemeral_command_reaches_the_router_as_a_private_update
    router = RecordingRouter.new

    assert_equal 200, post(ephemeral_command_payload, router: router)

    assert_predicate router.updates.fetch(0), :private?
    assert_empty @answerer.answered
  end

  def test_an_error_while_handling_a_private_command_is_reported_privately_only
    assert_equal 200, post(ephemeral_command_payload(thread: 3), router: RecordingRouter.new(error: RuntimeError.new("boom")))

    assert_empty @public.messages
    notice = @private.sent.fetch(0)
    assert_equal [-1001, 3, 7], [notice[:target].chat_id, notice[:target].message_thread_id, notice[:target].receiver_user_id]
    assert_equal :reply, notice[:target].mode
  end

  def test_a_paused_instance_is_told_privately_when_it_presses_or_types
    [ephemeral_command_payload, callback_payload].each do |payload|
      @private.sent.clear
      post(payload, bot_lifecycle: FakeBotLifecycle.new(status: "paused"))

      assert_equal 1, @private.sent.length
      assert_empty @public.messages
    end
  end

  def test_private_delivery_that_fails_never_falls_back_to_the_group
    failing = Object.new
    def failing.send_ephemeral_message(**) = raise(PrismBot::MessageDeliveryError.new("bot.telegram.ephemeral.unconfirmed", "no"))
    sender = PrismBot::Adapters::Telegram::PrivateReplySender.new(public_sender: @public, ephemeral_sender: failing)

    assert_equal 200, post(ephemeral_command_payload, router: RecordingRouter.new(error: RuntimeError.new("boom")), sender: sender)
    assert_equal 200, post(callback_payload, bot_lifecycle: FakeBotLifecycle.new(status: "paused"), sender: sender)

    assert_empty @public.messages
  end

  def test_an_unauthorized_private_sender_gets_no_public_reply
    resolver = FakeActorResolver.new(denied_subject_ids: ["7"])

    assert_equal 200, post(ephemeral_command_payload, actor_resolver: resolver)

    assert_empty @public.messages
    assert_empty @private.sent
  end

  def test_a_button_press_is_routed_then_answered_once_with_no_text
    router = RecordingRouter.new

    assert_equal 200, post(callback_payload(id: "cb-77"), router: router)

    assert_equal "cb-77", router.updates.fetch(0).callback.id
    assert_equal ["cb-77"], @answerer.answered
  end

  def test_a_press_is_answered_even_when_it_is_refused_or_fails
    post(callback_payload(id: "denied"), allowed_chat_ids: [-5])
    post(callback_payload(id: "unauthorized"), actor_resolver: FakeActorResolver.new(denied_subject_ids: ["7"]))
    post(callback_payload(id: "failing"), router: RecordingRouter.new(error: RuntimeError.new("boom")))

    assert_equal %w[denied unauthorized failing], @answerer.answered
    assert_equal 1, @private.sent.length, "only the failure is reported, and only privately"
    assert_empty @public.messages
  end

  def test_a_failing_answer_changes_nothing_else
    @answerer = FakeCallbackAnswerer.new(error: PrismBot::MessageDeliveryError.new("bot.telegram.callback.answer_failed", "no"))
    router = RecordingRouter.new

    assert_equal 200, post(callback_payload, router: router)
    assert_equal 1, router.updates.length
  end

  def test_ordinary_updates_are_never_answered_as_callbacks
    post(telegram_payload)
    post({"update_id" => 1})

    assert_empty @answerer.answered
  end

  def test_an_open_command_reaches_the_router_for_a_person_hub_does_not_know_and_other_commands_do_not
    resolver = PrismBotTestSupport::FakeActorResolver.new(denied_subject_ids: [7])
    open = RecordingRouter.new
    assert_equal 200, post(ephemeral_command_payload(text: "/whisper"), router: open, actor_resolver: resolver,
      open_commands: %w[whisper])
    assert_equal 1, open.updates.length
    assert_equal "member", open.updates.fetch(0).actor.role
    assert_empty resolver.requests

    closed = RecordingRouter.new
    assert_equal 200, post(ephemeral_command_payload(text: "/publish hi"), router: closed, actor_resolver: resolver,
      open_commands: %w[whisper])
    assert_empty closed.updates
  end

  def test_a_bad_secret_answers_nothing
    app = webhook_app(router: RecordingRouter.new, callback_answerer: @answerer)
    status, = app.call(webhook_environment(callback_payload, secret: "wrong"))

    assert_equal 401, status
    assert_empty @answerer.answered
  end
end
