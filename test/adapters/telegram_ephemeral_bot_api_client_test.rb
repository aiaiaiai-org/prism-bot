# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class TelegramEphemeralBotApiClientTest < Minitest::Test
  Target = PrismBot::Domain::EphemeralTarget
  CHAT = -1001
  RECEIVER = 7

  def client(transport)
    PrismBot::Adapters::Telegram::EphemeralBotApiClient.new(token: "test-token", transport: transport)
  end

  def transport_returning(result, status: 200, ok: true)
    PrismBotTestSupport::FakeTransport.new(status: status, body: JSON.generate("ok" => ok, "result" => result))
  end

  def ephemeral_result(id: 31, receiver: RECEIVER, chat: CHAT, message_id: 0, **extra)
    {"message_id" => message_id, "ephemeral_message_id" => id, "receiver_user" => {"id" => receiver},
     "chat" => {"id" => chat}}.merge(extra)
  end

  def voice_result(**fields)
    ephemeral_result(**{"voice" => {"file_id" => "AwAD-voice", "duration" => 9}}.merge(fields))
  end

  def clip
    PrismBot::Domain::VoiceClip.new(audio: PrismBotTestSupport.ogg_opus(extra: "\xFF\x00audio".b), duration_seconds: 9)
  end

  def keyboard
    PrismBot::Domain::InlineKeyboard.new(rows: [[{text: "Поділитися з усіма", callback_data: "w:share"}]])
  end

  def payload_of(transport, index = 0)
    JSON.parse(transport.calls.fetch(index).fetch(:body))
  end

  def test_member_target_sends_to_the_chat_with_only_the_receiver
    transport = transport_returning(ephemeral_result)
    ref = client(transport).send_ephemeral_message(
      target: Target.to_member(chat_id: CHAT, receiver_user_id: RECEIVER, message_thread_id: 12),
      text: "🔒 Приватно · Whisper",
      reply_markup: keyboard
    )

    call = transport.calls.fetch(0)
    assert_equal "https://api.telegram.org/bottest-token/sendMessage", call.fetch(:url)
    body = payload_of(transport)
    assert_equal CHAT, body.fetch("chat_id")
    assert_equal 12, body.fetch("message_thread_id")
    assert_equal({"receiver_user_id" => RECEIVER}, body.fetch("ephemeral_message_parameters"))
    refute body.key?("reply_parameters")
    assert_equal [[{"text" => "Поділитися з усіма", "callback_data" => "w:share"}]],
      body.dig("reply_markup", "inline_keyboard")
    assert_equal PrismBot::Domain::EphemeralMessageRef.new(chat_id: CHAT, receiver_user_id: RECEIVER, ephemeral_message_id: 31), ref
  end

  def test_callback_target_answers_the_callback_without_naming_a_receiver
    transport = transport_returning(ephemeral_result)
    client(transport).send_ephemeral_message(
      target: Target.reply_to_callback(chat_id: CHAT, receiver_user_id: RECEIVER, callback_query_id: "cb-9"),
      text: "ok"
    )

    body = payload_of(transport)
    assert_equal({"callback_query_id" => "cb-9"}, body.fetch("ephemeral_message_parameters"))
    refute body.fetch("ephemeral_message_parameters").key?("replace_callback_query_message")
    refute body.key?("message_thread_id")
    refute body.key?("reply_markup")
  end

  def test_reply_target_replies_to_the_incoming_ephemeral_message
    transport = transport_returning(ephemeral_result)
    client(transport).send_ephemeral_message(
      target: Target.reply_to_ephemeral(chat_id: CHAT, receiver_user_id: RECEIVER, ephemeral_message_id: 4),
      text: "ok"
    )

    body = payload_of(transport)
    assert_equal({"receiver_user_id" => RECEIVER}, body.fetch("ephemeral_message_parameters"))
    assert_equal({"ephemeral_message_id" => 4}, body.fetch("reply_parameters"))
  end

  def test_a_response_that_is_not_confirmed_private_is_an_error_never_a_public_fallback
    target = Target.to_member(chat_id: CHAT, receiver_user_id: RECEIVER)
    [
      {"message_id" => 55, "chat" => {"id" => CHAT}},
      ephemeral_result(message_id: 55),
      ephemeral_result(receiver: 8),
      ephemeral_result(chat: -2002),
      ephemeral_result(id: 0),
      ephemeral_result.tap { _1.delete("receiver_user") },
      ephemeral_result.tap { _1.delete("ephemeral_message_id") },
      true
    ].each do |result|
      transport = transport_returning(result)
      error = assert_raises(PrismBot::MessageDeliveryError, result.inspect) do
        client(transport).send_ephemeral_message(target: target, text: "secret")
      end
      assert_equal "bot.telegram.ephemeral.unconfirmed", error.code
      assert_equal 1, transport.calls.length, "no second, public request may follow"
    end
  end

  def test_text_is_never_shortened_and_must_not_be_blank
    transport = transport_returning(ephemeral_result)
    target = Target.to_member(chat_id: CHAT, receiver_user_id: RECEIVER)

    [("x" * 4097), "", "  \n ", nil, 5].each do |text|
      assert_raises(PrismBot::InputError) { client(transport).send_ephemeral_message(target: target, text: text) }
    end
    client(transport).send_ephemeral_message(target: target, text: "x" * 4096)
    assert_equal 1, transport.calls.length
  end

  def test_rejects_a_target_or_keyboard_of_the_wrong_kind
    transport = transport_returning(ephemeral_result)

    assert_raises(PrismBot::InputError) { client(transport).send_ephemeral_message(target: {chat_id: CHAT}, text: "x") }
    assert_raises(PrismBot::InputError) do
      client(transport).send_ephemeral_message(
        target: Target.to_member(chat_id: CHAT, receiver_user_id: RECEIVER), text: "x", reply_markup: [["a"]]
      )
    end
    assert_empty transport.calls
  end

  def test_edit_addresses_the_message_by_chat_receiver_and_ephemeral_id
    transport = transport_returning(true)
    ref = PrismBot::Domain::EphemeralMessageRef.new(chat_id: CHAT, receiver_user_id: RECEIVER, ephemeral_message_id: 31)

    assert_nil client(transport).edit_ephemeral_message(ref: ref, text: "Готово", reply_markup: keyboard)

    assert_equal "https://api.telegram.org/bottest-token/editEphemeralMessageText", transport.calls.fetch(0).fetch(:url)
    body = payload_of(transport)
    assert_equal CHAT, body.fetch("chat_id")
    assert_equal RECEIVER, body.fetch("receiver_user_id")
    assert_equal 31, body.fetch("ephemeral_message_id")
    assert_equal "Готово", body.fetch("text")
    assert_equal "w:share", body.dig("reply_markup", "inline_keyboard", 0, 0, "callback_data")
  end

  def test_edit_without_confirmation_or_with_a_wrong_reference_fails
    ref = PrismBot::Domain::EphemeralMessageRef.new(chat_id: CHAT, receiver_user_id: RECEIVER, ephemeral_message_id: 31)

    error = assert_raises(PrismBot::MessageDeliveryError) do
      client(transport_returning(false)).edit_ephemeral_message(ref: ref, text: "x")
    end
    assert_equal "bot.telegram.ephemeral.unconfirmed", error.code
    assert_raises(PrismBot::InputError) { client(transport_returning(true)).edit_ephemeral_message(ref: 31, text: "x") }
  end

  def test_delete_addresses_the_message_by_chat_receiver_and_ephemeral_id
    transport = transport_returning(true)
    ref = PrismBot::Domain::EphemeralMessageRef.new(chat_id: CHAT, receiver_user_id: RECEIVER, ephemeral_message_id: 31)

    assert_nil client(transport).delete_ephemeral_message(ref: ref)

    assert_equal "https://api.telegram.org/bottest-token/deleteEphemeralMessage", transport.calls.fetch(0).fetch(:url)
    assert_equal({"chat_id" => CHAT, "receiver_user_id" => RECEIVER, "ephemeral_message_id" => 31}, payload_of(transport))
  end

  def test_delete_without_confirmation_or_with_a_wrong_reference_fails_and_never_falls_back
    ref = PrismBot::Domain::EphemeralMessageRef.new(chat_id: CHAT, receiver_user_id: RECEIVER, ephemeral_message_id: 31)

    error = assert_raises(PrismBot::MessageDeliveryError) { client(transport_returning(false)).delete_ephemeral_message(ref: ref) }
    assert_equal "bot.telegram.ephemeral.unconfirmed", error.code
    assert_raises(PrismBot::InputError) { client(transport_returning(true)).delete_ephemeral_message(ref: 31) }
  end

  def test_ephemeral_voice_is_uploaded_as_one_multipart_voice_with_ephemeral_parameters
    transport = transport_returning(voice_result)
    receipt = client(transport).send_ephemeral_voice(
      target: Target.reply_to_callback(chat_id: CHAT, receiver_user_id: RECEIVER, callback_query_id: "cb-9", message_thread_id: 12),
      clip: clip,
      caption: "🔒 Приватно · Whisper"
    )

    call = transport.calls.fetch(0)
    assert_equal "https://api.telegram.org/bottest-token/sendVoice", call.fetch(:url)
    assert_match %r{\Amultipart/form-data; boundary=prism-bot-\h{32}\z}, call.fetch(:headers).fetch("content-type")
    body = call.fetch(:body)
    assert_equal Encoding::BINARY, body.encoding
    assert_includes body, %(name="chat_id"\r\n\r\n#{CHAT}\r\n).b
    assert_includes body, %(name="message_thread_id"\r\n\r\n12\r\n).b
    assert_includes body, %(name="ephemeral_message_parameters"\r\n\r\n{"callback_query_id":"cb-9"}\r\n).b
    assert_includes body, %(name="caption"\r\n\r\n🔒 Приватно · Whisper\r\n).b
    assert_includes body, %(name="duration"\r\n\r\n9\r\n).b
    assert_includes body, %(name="voice"; filename="voice.ogg"\r\nContent-Type: audio/ogg\r\n\r\n).b
    assert_includes body, clip.audio
    assert_predicate receipt, :ephemeral?
    assert_equal "AwAD-voice", receipt.file_id
    assert_equal 31, receipt.ephemeral_ref.ephemeral_message_id
  end

  def test_ephemeral_voice_replying_to_an_ephemeral_message_carries_reply_parameters
    transport = transport_returning(voice_result)
    client(transport).send_ephemeral_voice(
      target: Target.reply_to_ephemeral(chat_id: CHAT, receiver_user_id: RECEIVER, ephemeral_message_id: 4),
      clip: clip,
      caption: "🔒"
    )

    body = transport.calls.fetch(0).fetch(:body)
    assert_includes body, %(name="reply_parameters"\r\n\r\n{"ephemeral_message_id":4}\r\n).b
    assert_includes body, %(name="ephemeral_message_parameters"\r\n\r\n{"receiver_user_id":7}\r\n).b
  end

  def test_ephemeral_voice_must_come_back_as_a_native_voice_for_the_receiver
    target = Target.to_member(chat_id: CHAT, receiver_user_id: RECEIVER)
    [
      ephemeral_result.merge("audio" => {"file_id" => "a"}),
      ephemeral_result.merge("document" => {"file_id" => "d"}),
      voice_result(receiver: 8),
      voice_result(message_id: 77)
    ].each do |result|
      transport = transport_returning(result)
      assert_raises(PrismBot::MessageDeliveryError, result.inspect) do
        client(transport).send_ephemeral_voice(target: target, clip: clip, caption: "🔒")
      end
      assert_equal 1, transport.calls.length
    end
  end

  def test_voice_needs_a_clip_and_a_caption_within_limits
    target = Target.to_member(chat_id: CHAT, receiver_user_id: RECEIVER)
    transport = transport_returning(voice_result)

    assert_raises(PrismBot::InputError) { client(transport).send_ephemeral_voice(target: target, clip: "audio", caption: "x") }
    assert_raises(PrismBot::InputError) { client(transport).send_ephemeral_voice(target: target, clip: clip, caption: "") }
    assert_raises(PrismBot::InputError) { client(transport).send_ephemeral_voice(target: target, clip: clip, caption: "x" * 1025) }
    assert_empty transport.calls
  end

  def test_public_voice_has_no_ephemeral_parameters_and_needs_a_real_message_id
    transport = transport_returning(
      {"message_id" => 88, "chat" => {"id" => CHAT}, "voice" => {"file_id" => "AwAD-public"}}
    )
    receipt = client(transport).send_public_voice(
      chat_id: CHAT, message_thread_id: 12, clip: clip, caption: "🔓 Для всіх · Whisper"
    )

    body = transport.calls.fetch(0).fetch(:body)
    refute_includes body, "ephemeral_message_parameters".b
    refute_includes body, "reply_parameters".b
    assert_includes body, %(name="caption"\r\n\r\n🔓 Для всіх · Whisper\r\n).b
    refute_predicate receipt, :ephemeral?
    assert_equal 88, receipt.message_id
  end

  def test_public_voice_rejects_an_ephemeral_looking_or_misplaced_result
    [
      {"message_id" => 0, "chat" => {"id" => CHAT}, "voice" => {"file_id" => "v"}},
      {"message_id" => 88, "ephemeral_message_id" => 3, "chat" => {"id" => CHAT}, "voice" => {"file_id" => "v"}},
      {"message_id" => 88, "chat" => {"id" => -2002}, "voice" => {"file_id" => "v"}},
      {"message_id" => 88, "chat" => {"id" => CHAT}}
    ].each do |result|
      assert_raises(PrismBot::MessageDeliveryError, result.inspect) do
        client(transport_returning(result)).send_public_voice(chat_id: CHAT, clip: clip, caption: "🔓")
      end
    end
    assert_raises(PrismBot::InputError) { client(transport_returning({})).send_public_voice(chat_id: 0, clip: clip, caption: "x") }
  end

  def test_rate_limits_and_rejections_carry_their_own_codes_without_telegram_text
    target = Target.to_member(chat_id: CHAT, receiver_user_id: RECEIVER)
    limited = PrismBotTestSupport::FakeTransport.new(
      status: 429, body: JSON.generate("ok" => false, "parameters" => {"retry_after" => 9})
    )
    rejected = PrismBotTestSupport::FakeTransport.new(
      status: 403, body: JSON.generate("ok" => false, "description" => "Forbidden: secret chat text")
    )

    error = assert_raises(PrismBot::DeliveryRateLimited) { client(limited).send_ephemeral_message(target: target, text: "x") }
    assert_equal 9, error.retry_after_seconds
    error = assert_raises(PrismBot::MessageDeliveryError) { client(rejected).send_ephemeral_message(target: target, text: "x") }
    assert_equal "bot.telegram.ephemeral.rejected", error.code
    refute_includes error.message, "secret"
    error = assert_raises(PrismBot::MessageDeliveryError) do
      client(rejected).send_ephemeral_voice(target: target, clip: clip, caption: "x")
    end
    assert_equal "bot.telegram.voice.rejected", error.code
  end

  def test_unavailable_telegram_is_a_delivery_error
    failing = Object.new
    def failing.call(**) = raise(PrismBot::TransportError.new("bot.http.unavailable", "down"))

    error = assert_raises(PrismBot::MessageDeliveryError) do
      client(failing).send_ephemeral_message(target: Target.to_member(chat_id: CHAT, receiver_user_id: RECEIVER), text: "x")
    end
    assert_equal "bot.telegram.unavailable", error.code
  end

  def test_an_empty_token_is_a_configuration_error
    assert_raises(PrismBot::ConfigurationError) do
      PrismBot::Adapters::Telegram::EphemeralBotApiClient.new(token: "", transport: PrismBotTestSupport::FakeTransport.new)
    end
  end
end
