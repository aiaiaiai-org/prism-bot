# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class WebhookObservationTest < Minitest::Test
  include PrismBotTestSupport

  Telegram = PrismBot::Channels::Telegram

  def setup
    @seen = []
    @log = StringIO.new
  end

  def post(payload, observer: nil, router: RecordingRouter.new, **options)
    observer ||= Telegram::ObserverChain.new(observers: [->(o) { @seen << o }], logger: Logger.new(@log))
    app = webhook_app(
      router: router, observation_parser: Telegram::ObservationParser.new, observer: observer,
      logger: Logger.new(@log), **options
    )
    status, = app.call(webhook_environment(payload))
    status
  end

  def group(text: "Привіт", user_id: 7, chat_id: -1001, **extra)
    payload = telegram_payload(text: text, user_id: user_id, chat_id: chat_id)
    payload["message"].merge!("message_id" => 301, "date" => 1_700_000_000, **extra)
    payload
  end

  def test_a_group_message_from_someone_who_never_onboarded_is_observed
    assert_equal 200, post(group, actor_resolver: FakeActorResolver.new(denied_subject_ids: ["7"]))

    assert_equal ["Привіт"], @seen.map(&:text)
  end

  def test_a_command_is_observed_and_still_routed
    router = RecordingRouter.new

    post(group(text: "/help"), router: router)

    assert_predicate @seen.fetch(0), :command?
    assert_equal ["/help"], router.updates.map(&:text)
  end

  def test_an_observer_that_fails_changes_nothing_else
    failing = ->(_observation) { raise "секрет з чату" }
    router = RecordingRouter.new

    assert_equal 200, post(group(text: "/help"), observer: failing, router: router)

    assert_equal 1, router.updates.length
    assert_includes @log.string, "observation_failed class=RuntimeError"
    refute_includes @log.string, "секрет"
  end

  def test_only_allowed_chats_are_observed
    post(group(chat_id: -1001), allowed_chat_ids: [-5])
    post(group(chat_id: -5), allowed_chat_ids: [-5])

    assert_equal [-5], @seen.map(&:chat_id)
  end

  def test_ephemeral_commands_and_button_presses_are_not_observed
    post(ephemeral_command_payload(text: "/whisper секретний запит"))
    post(callback_payload)

    assert_empty @seen
  end

  def test_nothing_is_observed_for_a_bad_secret_or_without_an_observer
    app = webhook_app(router: RecordingRouter.new, observation_parser: Telegram::ObservationParser.new,
      observer: ->(o) { @seen << o })
    status, = app.call(webhook_environment(group, secret: "wrong"))

    assert_equal 401, status
    assert_empty @seen
    assert_equal 200, webhook_app(router: RecordingRouter.new).call(webhook_environment(group)).first
  end

  def test_an_edit_is_observed_even_though_it_is_not_routed
    edit = {"update_id" => 60, "edited_message" => group.fetch("message")}
    router = RecordingRouter.new

    assert_equal 200, post(edit, router: router)

    assert_predicate @seen.fetch(0), :edited?
    assert_empty router.updates
  end
end
