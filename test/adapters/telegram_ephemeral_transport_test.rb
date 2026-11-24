# © 2026 aiaiaiai · aiaiaiai.org

require "test_helper"

class TelegramEphemeralTransportTest < Minitest::Test
  def setup
    @target = {chat_id: -100123, receiver_user_id: 42, message_thread_id: 7}
    @message = {
      "chat" => {"id" => -100123}, "receiver_user" => {"id" => 42},
      "message_thread_id" => 7, "ephemeral_message_id" => 19
    }
  end

  def client(result, status: 200)
    @transport = PrismBotTestSupport::FakeTransport.new(
      status: status, body: JSON.generate("ok" => status == 200, "result" => result)
    )
    PrismBot::Adapters::Telegram::BotApiClient.new(token: "test-token", transport: @transport)
  end

  def test_private_message_requires_and_verifies_recipient_and_topic
    result = client(@message).send_ephemeral_message(**@target, text: "private")
    assert_equal 19, result.fetch("ephemeral_message_id")
    payload = JSON.parse(@transport.calls.first.fetch(:body))
    assert_equal({"receiver_user_id" => 42}, payload.fetch("ephemeral_message_parameters"))
    assert_equal 7, payload.fetch("message_thread_id")
  end

  def test_invalid_recipient_is_not_sent
    sender = client(@message)
    assert_raises(PrismBot::InputError) do
      sender.send_ephemeral_message(**@target.merge(receiver_user_id: nil), text: "private")
    end
    assert_empty @transport.calls
  end

  def test_public_or_wrong_recipient_result_is_rejected_without_fallback
    [@message.reject { |key, _| key == "receiver_user" }, @message.merge("receiver_user" => {"id" => 99})].each do |result|
      sender = client(result)
      assert_raises(PrismBot::MessageDeliveryError) do
        sender.send_ephemeral_message(**@target, text: "private")
      end
      assert_equal 1, @transport.calls.size
    end
  end

  def test_edits_same_ephemeral_message
    sender = client(true)
    assert sender.edit_ephemeral_message(chat_id: -100123, receiver_user_id: 42, ephemeral_message_id: 19, text: "ready")
    call = @transport.calls.first
    assert call.fetch(:url).end_with?("/editEphemeralMessageText")
    assert_equal 19, JSON.parse(call.fetch(:body)).fetch("ephemeral_message_id")
  end

  def test_private_voice_uses_multipart_send_voice_and_protected_recipient
    audio = "OggS\x00OpusHead\x00".b
    result = @message.merge("voice" => {"file_id" => "voice_id"})
    assert_equal result, client(result).send_ephemeral_voice(**@target, audio: audio, caption: "private")
    call = @transport.calls.first
    assert call.fetch(:url).end_with?("/sendVoice")
    assert_match(/multipart\/form-data/, call.fetch(:headers).fetch("content-type"))
    assert_includes call.fetch(:body), '{"receiver_user_id":42}'
    assert_includes call.fetch(:body), audio
    assert_includes call.fetch(:body), 'name="protect_content"'
  end

  def test_voice_rejects_nonvoice_and_never_retries_publicly
    sender = client(@message)
    assert_raises(PrismBot::MessageDeliveryError) do
      sender.send_ephemeral_voice(**@target, audio: "OggS\x00OpusHead".b, caption: "private")
    end
    assert_equal 1, @transport.calls.size
  end

  def test_public_voice_is_a_separate_explicit_operation
    result = {"chat" => {"id" => -100123}, "message_id" => 20, "message_thread_id" => 7, "voice" => {"file_id" => "voice_id"}}
    sender = client(result)
    assert_equal result, sender.send_public_voice(chat_id: -100123, message_thread_id: 7, file_id: "voice_id", caption: "public")
    payload = JSON.parse(@transport.calls.first.fetch(:body))
    refute payload.key?("ephemeral_message_parameters")
    assert_equal "voice_id", payload.fetch("voice")
  end
end
