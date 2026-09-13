# © 2026 aiaiaiai · aiaiaiai.org

require "test_helper"

class TelegramBotApiClientTest < Minitest::Test
  def success_transport(message_id: 321)
    PrismBotTestSupport::FakeTransport.new(
      body: JSON.generate("ok" => true, "result" => {"message_id" => message_id})
    )
  end

  def client(transport)
    PrismBot::Adapters::Telegram::BotApiClient.new(token: "test-token", transport: transport)
  end

  def test_delivers_to_forum_topic_and_returns_provider_identity
    transport = success_transport
    result = client(transport).deliver_message(
      chat_id: -100123,
      message_thread_id: 44,
      text: "Digest https://example.test/source",
      idempotency_key: "delivery-1"
    )

    payload = JSON.parse(transport.calls.fetch(0).fetch(:body))
    assert_equal(-100123, payload.fetch("chat_id"))
    assert_equal 44, payload.fetch("message_thread_id")
    assert_equal "Digest https://example.test/source", payload.fetch("text")
    assert_equal({"is_disabled" => true}, payload.fetch("link_preview_options"))
    refute payload.key?("parse_mode")
    refute payload.key?("entities")
    refute payload.key?("idempotency_key")
    assert_equal 321, result.provider_message_id
    assert_equal "delivery-1", result.idempotency_key
  end

  def test_topic_is_optional
    transport = success_transport
    client(transport).deliver_message(chat_id: -100123, text: "Hello", idempotency_key: "delivery-2")

    payload = JSON.parse(transport.calls.fetch(0).fetch(:body))
    refute payload.key?("message_thread_id")
  end

  def test_maps_rate_limit_with_retry_after
    transport = PrismBotTestSupport::FakeTransport.new(
      status: 429,
      body: JSON.generate("ok" => false, "parameters" => {"retry_after" => 17})
    )

    error = assert_raises(PrismBot::DeliveryRateLimited) do
      client(transport).deliver_message(chat_id: -100123, text: "Hello", idempotency_key: "delivery-3")
    end
    assert_equal "bot.telegram.rate_limited", error.code
    assert_equal 17, error.retry_after_seconds
  end

  def test_rejects_invalid_or_incomplete_provider_success
    [
      PrismBotTestSupport::FakeTransport.new(body: "not-json"),
      PrismBotTestSupport::FakeTransport.new(body: JSON.generate("ok" => true, "result" => {}))
    ].each do |transport|
      assert_raises(PrismBot::MessageDeliveryError) do
        client(transport).deliver_message(chat_id: -100123, text: "Hello", idempotency_key: "delivery-4")
      end
    end
  end

  def test_outbound_delivery_never_silently_truncates
    transport = success_transport
    assert_raises(PrismBot::InputError) do
      client(transport).deliver_message(
        chat_id: -100123,
        text: "x" * (PrismBot::Adapters::Telegram::BotApiClient::MAX_MESSAGE_CHARACTERS + 1),
        idempotency_key: "delivery-5"
      )
    end
    assert_empty transport.calls
  end

  def test_rejects_invalid_thread_and_idempotency_key_before_transport
    transport = success_transport
    assert_raises(PrismBot::InputError) do
      client(transport).deliver_message(
        chat_id: -100123,
        message_thread_id: 0,
        text: "Hello",
        idempotency_key: "delivery 6"
      )
    end
    assert_empty transport.calls
  end

  def test_legacy_reply_sender_keeps_existing_truncation_behavior
    transport = success_transport
    assert_nil client(transport).send_message(
      chat_id: -100123,
      text: "x" * (PrismBot::Adapters::Telegram::BotApiClient::MAX_MESSAGE_CHARACTERS + 50)
    )

    payload = JSON.parse(transport.calls.fetch(0).fetch(:body))
    assert_equal PrismBot::Adapters::Telegram::BotApiClient::MAX_MESSAGE_CHARACTERS, payload.fetch("text").length
    refute payload.key?("link_preview_options")
  end

  def test_interactive_reply_includes_topic_without_enabling_markup
    transport = success_transport
    client(transport).send_message(chat_id: -100123, text: "<Context Card>", message_thread_id: 13)

    payload = JSON.parse(transport.calls.fetch(0).fetch(:body))
    assert_equal 13, payload.fetch("message_thread_id")
    assert_equal "<Context Card>", payload.fetch("text")
    refute payload.key?("parse_mode")
  end

  def test_invalid_reply_topic_never_reaches_transport
    transport = success_transport
    [0, -1, false, "13"].each do |thread_id|
      assert_raises(PrismBot::InputError) do
        client(transport).send_message(chat_id: -100123, text: "Hello", message_thread_id: thread_id)
      end
    end
    assert_empty transport.calls
  end
end
