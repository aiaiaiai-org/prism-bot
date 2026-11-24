# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class ObservationTest < Minitest::Test
  include PrismBotTestSupport

  Telegram = PrismBot::Channels::Telegram

  def group_payload(text: "Привіт усім", update_id: 50, chat_id: -1001, user_id: 7, message_id: 301, date: 1_700_000_000,
    thread: nil, key: "message", extra: {})
    message = {
      "message_id" => message_id, "date" => date, "text" => text,
      "chat" => {"id" => chat_id, "type" => "supergroup", "title" => "Група"},
      "from" => {"id" => user_id, "is_bot" => false, "first_name" => "Ада", "last_name" => "Лавлейс", "username" => "ada"}
    }
    message["message_thread_id"] = thread if thread
    {"update_id" => update_id, key => message.merge(extra)}
  end

  def parse(payload)
    Telegram::ObservationParser.new.call(payload)
  end

  def test_reads_a_group_message_with_everything_an_observer_needs
    observation = parse(group_payload(thread: 12))

    assert_equal [50, -1001, 12, 301, 7], [observation.update_id, observation.chat_id, observation.message_thread_id, observation.message_id, observation.author_id]
    assert_equal ["Привіт усім", "ada", "Ада Лавлейс", 1_700_000_000], [observation.text, observation.username, observation.display_name, observation.sent_at]
    refute_predicate observation, :edited?
    refute_predicate observation, :command?
    assert_predicate observation, :frozen?
  end

  def test_an_edit_keeps_the_original_date_and_is_marked_edited
    observation = parse(group_payload(key: "edited_message", update_id: 51, extra: {"edit_date" => 1_700_000_999}))

    assert_predicate observation, :edited?
    assert_equal [51, 1_700_000_000], [observation.update_id, observation.sent_at]
  end

  def test_a_caption_is_observed_and_text_wins_when_both_exist
    captioned = group_payload.tap { |p| p["message"].delete("text"); p["message"]["caption"] = "Підпис" }

    assert_equal "Підпис", parse(captioned).text
    assert_equal "Текст", parse(group_payload(text: "Текст", extra: {"caption" => "Підпис"})).text
  end

  def test_a_slash_command_is_flagged_not_hidden
    assert_predicate parse(group_payload(text: "/whisper 5")), :command?
  end

  def test_a_person_without_a_username_has_no_username
    payload = group_payload.tap { |p| p["message"]["from"].delete("username") }

    assert_nil parse(payload).username
  end

  def test_private_messages_are_never_observed
    [{"ephemeral_message_id" => 5}, {"receiver_user" => {"id" => 7}}, {"message_id" => 0}].each do |marker|
      assert_nil parse(group_payload(extra: marker)), marker.inspect
    end
  end

  def test_only_text_from_human_group_members_is_observed
    private_chat = group_payload.tap { |p| p["message"]["chat"]["type"] = "private" }
    channel = group_payload.tap { |p| p["message"]["chat"]["type"] = "channel" }
    bot = group_payload.tap { |p| p["message"]["from"]["is_bot"] = true }
    anonymous = group_payload(extra: {"sender_chat" => {"id" => -9, "type" => "channel"}})
    via_bot = group_payload(extra: {"via_bot" => {"id" => 5, "is_bot" => true}})
    sticker = group_payload.tap { |p| p["message"].delete("text"); p["message"]["sticker"] = {"file_id" => "x"} }
    no_sender = group_payload.tap { |p| p["message"].delete("from") }
    empty = group_payload(text: "")

    [private_chat, channel, bot, anonymous, via_bot, sticker, no_sender, empty].each do |payload|
      assert_nil parse(payload), payload.inspect
    end
    assert_nil parse({"update_id" => 1, "callback_query" => {"id" => "c"}})
    assert_nil parse("not a hash")
  end

  def test_malformed_content_is_ignored_never_raised
    [
      group_payload(message_id: "x"), group_payload(date: 0), group_payload(user_id: -1), group_payload(update_id: nil),
      group_payload(chat_id: 0), group_payload(thread: 0)
    ].each do |payload|
      assert_nil parse(payload), payload.inspect
    end
  end

  def test_observation_validates_its_own_fields
    surface = Telegram::SurfaceContext.new(chat_id: -1, chat_type: "supergroup")
    valid = {update_id: 1, surface_context: surface, message_id: 2, author_id: 3, text: "x", sent_at: 4, display_name: "A"}

    assert Telegram::Observation.new(**valid)
    [{text: ""}, {sent_at: 0}, {author_id: 0}, {edited: "yes"}, {display_name: nil},
      {surface_context: Telegram::SurfaceContext.new(chat_id: 5, chat_type: "private")}].each do |bad|
      assert_raises(PrismBot::InputError, bad.inspect) { Telegram::Observation.new(**valid.merge(bad)) }
    end
  end

  def test_chain_isolates_failing_observers_and_logs_only_the_class
    log = StringIO.new
    seen = []
    chain = Telegram::ObserverChain.new(
      observers: [->(_o) { raise "секрет з чату" }, ->(o) { seen << o.text }],
      logger: Logger.new(log)
    )

    assert_nil chain.call(parse(group_payload))

    assert_equal ["Привіт усім"], seen
    assert_includes log.string, "observer_failed class=RuntimeError"
    refute_includes log.string, "секрет"
  end

  def test_composition_collects_observers_and_rejects_non_callables
    observer = ->(_o) { }
    base = PrismBot::Client::Composition.new(
      command_handlers: {}, fallback: ->(**) { }, presenter: Telegram::ResultPresenter.new, observers: [observer]
    )

    assert_equal [observer], base.observers
    assert_equal 2, base.with(observers: [observer]).observers.length
    assert_empty PrismBot::Client::Composition.new(command_handlers: {}, fallback: ->(**) { }, presenter: Telegram::ResultPresenter.new).observers
    assert_raises(ArgumentError) { base.with(observers: [1]) }
  end
end
