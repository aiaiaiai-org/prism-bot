# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class TelegramPrivateReplySenderTest < Minitest::Test
  include PrismBotTestSupport

  Target = PrismBot::Domain::EphemeralTarget

  def setup
    @public = FakeMessageSender.new
    @private = FakeEphemeralSender.new
    @sender = PrismBot::Adapters::Telegram::PrivateReplySender.new(public_sender: @public, ephemeral_sender: @private)
  end

  def test_a_reply_without_a_target_is_public
    @sender.send_message(chat_id: -1001, text: "hi", message_thread_id: 4, location_request: "Де ти?")

    assert_equal [{"chat_id" => -1001, "text" => "hi", "message_thread_id" => 4, "location_request" => "Де ти?"}], @public.messages
    assert_empty @private.sent
  end

  def test_a_reply_with_a_target_is_private_and_never_public
    target = Target.reply_to_callback(chat_id: -1001, receiver_user_id: 7, callback_query_id: "cb", message_thread_id: 4)

    assert_nil @sender.send_message(chat_id: -1001, message_thread_id: 4, text: "🔒 секрет", ephemeral: target)

    assert_empty @public.messages
    assert_equal [{target: target, text: "🔒 секрет", reply_markup: nil}], @private.sent
  end

  def test_a_private_reply_that_fails_is_not_resent_publicly
    failing = Object.new
    def failing.send_ephemeral_message(**) = raise(PrismBot::MessageDeliveryError.new("bot.telegram.ephemeral.rejected", "no"))
    sender = PrismBot::Adapters::Telegram::PrivateReplySender.new(public_sender: @public, ephemeral_sender: failing)

    assert_raises(PrismBot::MessageDeliveryError) do
      sender.send_message(chat_id: -1001, text: "x", ephemeral: Target.to_member(chat_id: -1001, receiver_user_id: 7))
    end
    assert_empty @public.messages
  end

  def test_rejects_a_target_for_another_chat_or_topic_or_with_a_reply_keyboard
    target = Target.to_member(chat_id: -1001, receiver_user_id: 7, message_thread_id: 4)

    [
      {chat_id: -2002, message_thread_id: 4},
      {chat_id: -1001, message_thread_id: 5},
      {chat_id: -1001, message_thread_id: nil},
      {chat_id: -1001, message_thread_id: 4, location_request: "Де ти?"}
    ].each do |arguments|
      assert_raises(PrismBot::InputError, arguments.inspect) do
        @sender.send_message(text: "x", ephemeral: target, **arguments)
      end
    end
    assert_raises(PrismBot::InputError) { @sender.send_message(chat_id: -1001, text: "x", ephemeral: {chat_id: -1001}) }
    assert_empty @public.messages
    assert_empty @private.sent
  end

  def test_the_plain_sender_refuses_a_private_reply_instead_of_posting_it
    transport = FakeTransport.new
    plain = PrismBot::Adapters::Telegram::BotApiClient.new(token: "t", transport: transport)

    error = assert_raises(PrismBot::InputError) do
      plain.send_message(chat_id: -1001, text: "x", ephemeral: Target.to_member(chat_id: -1001, receiver_user_id: 7))
    end
    assert_equal "bot.telegram.ephemeral.unsupported", error.code
    assert_empty transport.calls
  end

  def test_answers_a_callback_with_an_optional_short_notice
    transport = FakeTransport.new(body: JSON.generate("ok" => true, "result" => true))
    plain = PrismBot::Adapters::Telegram::BotApiClient.new(token: "t", transport: transport)

    assert_nil plain.answer_callback_query(callback_query_id: "cb-1")
    assert_nil plain.answer_callback_query(callback_query_id: "cb-2", text: "Готово")

    assert_equal "https://api.telegram.org/bott/answerCallbackQuery", transport.calls.fetch(0).fetch(:url)
    assert_equal({"callback_query_id" => "cb-1"}, JSON.parse(transport.calls.fetch(0).fetch(:body)))
    assert_equal({"callback_query_id" => "cb-2", "text" => "Готово"}, JSON.parse(transport.calls.fetch(1).fetch(:body)))
  end

  def test_callback_answer_validates_input_and_maps_rejection
    plain = PrismBot::Adapters::Telegram::BotApiClient.new(
      token: "t",
      transport: FakeTransport.new(status: 400, body: JSON.generate("ok" => false, "description" => "query is too old"))
    )

    assert_raises(PrismBot::InputError) { plain.answer_callback_query(callback_query_id: "") }
    assert_raises(PrismBot::InputError) { plain.answer_callback_query(callback_query_id: "c", text: "x" * 201) }
    error = assert_raises(PrismBot::MessageDeliveryError) { plain.answer_callback_query(callback_query_id: "c") }
    assert_equal "bot.telegram.callback.answer_failed", error.code
  end
end
