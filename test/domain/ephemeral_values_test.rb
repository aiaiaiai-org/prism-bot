# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class EphemeralValuesTest < Minitest::Test
  Target = PrismBot::Domain::EphemeralTarget

  def test_each_mode_requires_exactly_its_own_authority
    callback = Target.reply_to_callback(chat_id: -1001, receiver_user_id: 7, callback_query_id: "cb-1", message_thread_id: 5)
    reply = Target.reply_to_ephemeral(chat_id: -1001, receiver_user_id: 7, ephemeral_message_id: 3)
    member = Target.to_member(chat_id: -1001, receiver_user_id: 7)

    assert_equal %i[callback reply member], [callback, reply, member].map(&:mode)
    assert_equal 5, callback.message_thread_id
    assert_equal "cb-1", callback.callback_query_id
    assert_equal 3, reply.reply_ephemeral_message_id
    assert_nil member.callback_query_id
  end

  def test_rejects_an_authority_that_does_not_match_the_mode
    assert_raises(PrismBot::InputError) { Target.new(mode: :member, chat_id: -1, receiver_user_id: 7, callback_query_id: "x") }
    assert_raises(PrismBot::InputError) { Target.new(mode: :callback, chat_id: -1, receiver_user_id: 7) }
    assert_raises(PrismBot::InputError) { Target.new(mode: :reply, chat_id: -1, receiver_user_id: 7) }
    assert_raises(PrismBot::InputError) do
      Target.new(mode: :callback, chat_id: -1, receiver_user_id: 7, callback_query_id: "x", reply_ephemeral_message_id: 2)
    end
    assert_raises(PrismBot::InputError) { Target.new(mode: :public, chat_id: -1, receiver_user_id: 7) }
  end

  def test_rejects_an_unknown_receiver_chat_topic_or_callback
    assert_raises(PrismBot::InputError) { Target.to_member(chat_id: -1, receiver_user_id: nil) }
    assert_raises(PrismBot::InputError) { Target.to_member(chat_id: -1, receiver_user_id: 0) }
    assert_raises(PrismBot::InputError) { Target.to_member(chat_id: 0, receiver_user_id: 7) }
    assert_raises(PrismBot::InputError) { Target.to_member(chat_id: -1, receiver_user_id: 7, message_thread_id: 0) }
    assert_raises(PrismBot::InputError) { Target.reply_to_callback(chat_id: -1, receiver_user_id: 7, callback_query_id: "") }
    assert_raises(PrismBot::InputError) { Target.reply_to_callback(chat_id: -1, receiver_user_id: 7, callback_query_id: "a\nb") }
  end

  def test_targets_compare_by_value_and_are_immutable
    one = Target.to_member(chat_id: -1, receiver_user_id: 7)
    two = Target.to_member(chat_id: -1, receiver_user_id: 7)

    assert_equal one, two
    assert_equal one.hash, two.hash
    refute_equal one, Target.to_member(chat_id: -1, receiver_user_id: 8)
    assert_predicate one, :frozen?
  end

  def test_message_ref_needs_chat_receiver_and_id
    ref = PrismBot::Domain::EphemeralMessageRef.new(chat_id: -1, receiver_user_id: 7, ephemeral_message_id: 4)

    assert_equal 4, ref.ephemeral_message_id
    assert_equal ref, PrismBot::Domain::EphemeralMessageRef.new(chat_id: -1, receiver_user_id: 7, ephemeral_message_id: 4)
    [{chat_id: 0}, {receiver_user_id: 0}, {ephemeral_message_id: 0}, {ephemeral_message_id: "4"}].each do |bad|
      assert_raises(PrismBot::InputError) do
        PrismBot::Domain::EphemeralMessageRef.new(**{chat_id: -1, receiver_user_id: 7, ephemeral_message_id: 4}.merge(bad))
      end
    end
  end

  def test_keyboard_holds_callback_buttons_within_telegram_limits
    keyboard = PrismBot::Domain::InlineKeyboard.new(
      rows: [[{text: "Далі", callback_data: "w:1"}, {text: "Скасувати", callback_data: "w:0"}]]
    )

    assert_equal %w[w:1 w:0], keyboard.rows.first.map(&:callback_data)
    assert_predicate keyboard, :frozen?
    assert_predicate keyboard.rows.first, :frozen?
  end

  def test_keyboard_rejects_oversized_or_empty_input
    keyboard = PrismBot::Domain::InlineKeyboard
    assert_raises(PrismBot::InputError) { keyboard.new(rows: []) }
    assert_raises(PrismBot::InputError) { keyboard.new(rows: [[]]) }
    assert_raises(PrismBot::InputError) { keyboard.new(rows: [[{text: "", callback_data: "x"}]]) }
    assert_raises(PrismBot::InputError) { keyboard.new(rows: [[{text: "a\nb", callback_data: "x"}]]) }
    assert_raises(PrismBot::InputError) { keyboard.new(rows: [[{text: "a", callback_data: ""}]]) }
    assert_raises(PrismBot::InputError) { keyboard.new(rows: [[{text: "a", callback_data: "я" * 33}]]) }
    assert_raises(PrismBot::InputError) { keyboard.new(rows: [Array.new(9) { {text: "a", callback_data: "x"} }]) }
    assert_raises(PrismBot::InputError) { keyboard.new(rows: Array.new(21) { [{text: "a", callback_data: "x"}] }) }
  end

  def test_keyboard_callback_data_is_limited_in_bytes_not_characters
    PrismBot::Domain::InlineKeyboard.new(rows: [[{text: "a", callback_data: "я" * 32}]])
    assert_raises(PrismBot::InputError) do
      PrismBot::Domain::InlineKeyboard.new(rows: [[{text: "a", callback_data: "я" * 32 + "x"}]])
    end
  end

  def test_voice_clip_accepts_only_ogg_opus_with_a_duration
    clip = PrismBot::Domain::VoiceClip.new(audio: PrismBotTestSupport.ogg_opus, duration_seconds: 12)

    assert_equal 12, clip.duration_seconds
    assert_equal Encoding::BINARY, clip.audio.encoding
    assert_predicate clip, :frozen?
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceClip.new(audio: "ID3 not ogg".b, duration_seconds: 5) }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceClip.new(audio: "OggS#{"\0" * 24}Vorbis", duration_seconds: 5) }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceClip.new(audio: "", duration_seconds: 5) }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceClip.new(audio: PrismBotTestSupport.ogg_opus, duration_seconds: 0) }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceClip.new(audio: PrismBotTestSupport.ogg_opus, duration_seconds: 1.5) }
  end

  def test_voice_receipt_is_either_public_or_ephemeral_never_both_or_neither
    ref = PrismBot::Domain::EphemeralMessageRef.new(chat_id: -1, receiver_user_id: 7, ephemeral_message_id: 4)

    assert_predicate PrismBot::Domain::VoiceReceipt.new(file_id: "f", ephemeral_ref: ref), :ephemeral?
    refute_predicate PrismBot::Domain::VoiceReceipt.new(file_id: "f", message_id: 9), :ephemeral?
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceReceipt.new(file_id: "f") }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceReceipt.new(file_id: "f", message_id: 9, ephemeral_ref: ref) }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceReceipt.new(file_id: "", message_id: 9) }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::VoiceReceipt.new(file_id: "f", message_id: 0) }
  end
end
