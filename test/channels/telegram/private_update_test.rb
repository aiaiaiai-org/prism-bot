# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class PrivateUpdateTest < Minitest::Test
  include PrismBotTestSupport

  Telegram = PrismBot::Channels::Telegram

  def parse(payload)
    Telegram::UpdateParser.new.call(payload)
  end

  def test_an_ephemeral_command_is_private_and_replies_to_its_sender_only
    update = parse(ephemeral_command_payload(thread: 12))

    assert_predicate update, :private?
    assert_equal "/whisper", update.text
    assert_equal 5, update.ephemeral_message_id
    target = update.reply_target.fetch(:ephemeral)
    assert_equal :reply, target.mode
    assert_equal [-1001, 12, 7, 5], [target.chat_id, target.message_thread_id, target.receiver_user_id, target.reply_ephemeral_message_id]
    assert_equal({chat_id: -1001, message_thread_id: 12}, update.reply_target.reject { |key, _| key == :ephemeral })
  end

  def test_an_ordinary_message_stays_public_and_unchanged
    update = parse(telegram_payload)

    refute_predicate update, :private?
    assert_equal({chat_id: -1001}, update.reply_target)
  end

  def test_a_private_marker_without_a_usable_id_is_an_error_never_a_public_message
    [
      ephemeral_command_payload.tap { _1["message"].delete("ephemeral_message_id") },
      ephemeral_command_payload.tap { _1["message"].delete("ephemeral_message_id") && _1["message"]["receiver_user"] = {"id" => 7} },
      ephemeral_command_payload(ephemeral_message_id: 0),
      ephemeral_command_payload(ephemeral_message_id: "5")
    ].each do |payload|
      error = assert_raises(PrismBot::InputError, payload.inspect) { parse(payload) }
      assert_equal "bot.telegram.ephemeral.invalid", error.code
    end
  end

  def test_a_private_message_needs_a_human_sender
    payload = ephemeral_command_payload
    payload["message"]["from"] = {"id" => 9, "is_bot" => true}

    assert_raises(PrismBot::InputError) { parse(payload) }
  end

  def test_a_button_press_is_a_private_update_with_a_callback_target
    update = parse(callback_payload(data: "w:next:2", thread: 12, source_ephemeral: 8))

    assert_predicate update, :private?
    assert_equal "", update.text
    assert_equal 7, update.user_id
    assert_equal "cb-1", update.callback.id
    assert_equal ["w", "next:2"], [update.callback.route, update.callback.payload]
    target = update.reply_target.fetch(:ephemeral)
    assert_equal :callback, target.mode
    assert_equal ["cb-1", 12, 7], [target.callback_query_id, target.message_thread_id, target.receiver_user_id]
    ref = update.source_ephemeral_ref
    assert_equal [-1001, 7, 8], [ref.chat_id, ref.receiver_user_id, ref.ephemeral_message_id]
  end

  def test_a_press_on_a_public_message_has_no_source_ephemeral_message
    update = parse(callback_payload)

    assert_nil update.callback.source_ephemeral_message_id
    assert_nil update.source_ephemeral_ref
  end

  def test_presses_the_bot_cannot_answer_privately_are_ignored
    inaccessible = callback_payload.tap { _1["callback_query"]["message"]["date"] = 0 }
    by_bot = callback_payload.tap { _1["callback_query"]["from"]["is_bot"] = true }
    no_data = callback_payload.tap { _1["callback_query"].delete("data") }
    no_message = callback_payload.tap { _1["callback_query"].delete("message") }
    in_channel = callback_payload.tap { _1["callback_query"]["message"]["chat"]["type"] = "channel" }
    inline_mode = {"update_id" => 1, "callback_query" => {"id" => "x", "from" => {"id" => 7}, "data" => "w:go", "inline_message_id" => "abc"}}

    [inaccessible, by_bot, no_data, no_message, in_channel, inline_mode].each do |payload|
      assert_nil parse(payload), payload.inspect
    end
  end

  def test_malformed_callback_data_and_ids_are_errors
    assert_raises(PrismBot::InputError) { parse(callback_payload(data: "x" * 65)) }
    assert_raises(PrismBot::InputError) { parse(callback_payload(data: "")) }
    assert_raises(PrismBot::InputError) { parse(callback_payload(id: "")) }
    assert_raises(PrismBot::InputError) { parse(callback_payload.tap { _1["callback_query"]["from"].delete("id") }) }
    assert_raises(PrismBot::InputError) { parse(callback_payload(source_ephemeral: 0)) }
  end

  def test_callback_route_is_the_data_before_the_first_colon
    context = Telegram::CallbackContext.new(id: "c", data: "pick")
    assert_equal ["pick", ""], [context.route, context.payload]
  end

  def test_private_updates_survive_authorization
    update = parse(callback_payload)
    authorized = Telegram::AuthorizedUpdate.new(
      update: update, actor: PrismBot::Domain::HumanActor.new(canonical_id: "0x0sky", role: "owner")
    )

    assert_predicate authorized, :private?
    assert_equal update.reply_target, authorized.reply_target
    assert_equal "cb-1", authorized.callback.id
  end
end
