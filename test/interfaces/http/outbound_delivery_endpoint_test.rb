# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require_relative "../../test_helper"

class OutboundDeliveryEndpointTest < Minitest::Test
  class MessageSender
    attr_reader :request

    def deliver_message(**request)
      @request = request
      PrismBot::Domain::DeliveryResult.new(
        provider_message_id: 12345,
        idempotency_key: request.fetch(:idempotency_key)
      )
    end
  end

  def setup
    @sender = MessageSender.new
    @app = PrismBot::Interfaces::HTTP::OutboundDeliveryEndpoint.new(
      secret: PrismBot::Interfaces::HTTP::SharedSecret.new("d" * 32),
      message_sender: @sender,
      max_body_bytes: 1024
    )
  end

  def test_delivers_authenticated_request
    response = request(
      "d" * 32,
      JSON.generate(
        "chat_id" => -100123,
        "text" => "Hello",
        "idempotency_key" => "delivery-1",
        "message_thread_id" => 42
      )
    )

    assert_equal 200, response.status
    assert_equal(
      {
        chat_id: -100123,
        text: "Hello",
        idempotency_key: "delivery-1",
        message_thread_id: 42
      },
      @sender.request
    )
    assert_equal 12345, JSON.parse(response.body).dig("delivery", "provider_message_id")
    assert_equal "delivery-1", JSON.parse(response.body).dig("delivery", "idempotency_key")
  end

  def test_rejects_invalid_secret_before_delivery
    response = request(
      "x" * 32,
      JSON.generate("chat_id" => -100123, "text" => "Hello", "idempotency_key" => "delivery-1")
    )

    assert_equal 401, response.status
    refute @sender.request
  end

  def test_rejects_invalid_json
    response = request("d" * 32, "{")

    assert_equal 400, response.status
    assert_equal "bot.json.invalid", JSON.parse(response.body).dig("error", "code")
  end

  def test_maps_rate_limit
    sender = Object.new
    sender.define_singleton_method(:deliver_message) do |**|
      raise PrismBot::DeliveryRateLimited.new(
        "bot.telegram.rate_limited",
        "rate limited",
        retry_after_seconds: 17
      )
    end
    app = PrismBot::Interfaces::HTTP::OutboundDeliveryEndpoint.new(
      secret: PrismBot::Interfaces::HTTP::SharedSecret.new("d" * 32),
      message_sender: sender,
      max_body_bytes: 1024
    )

    response = Rack::MockRequest.new(app).post(
      "/api/v1/delivery",
      "CONTENT_TYPE" => "application/json",
      "HTTP_X_PRISM_BOT_DELIVERY_SECRET" => "d" * 32,
      input: JSON.generate("chat_id" => -100123, "text" => "Hello", "idempotency_key" => "delivery-1")
    )

    assert_equal 429, response.status
    assert_equal 17, JSON.parse(response.body).dig("error", "retry_after_seconds")
  end

  def test_sender_input_rejection_is_terminal_rather_than_retryable
    app = PrismBot::Interfaces::HTTP::OutboundDeliveryEndpoint.new(
      secret: PrismBot::Interfaces::HTTP::SharedSecret.new("d" * 32),
      message_sender: PrismBot::Adapters::Telegram::BotApiClient.new(
        token: "test-token",
        transport: ->(**) { flunk("an oversized payload must never reach Telegram") }
      ),
      max_body_bytes: 262_144
    )

    response = Rack::MockRequest.new(app).post(
      "/api/v1/delivery",
      "CONTENT_TYPE" => "application/json",
      "HTTP_X_PRISM_BOT_DELIVERY_SECRET" => "d" * 32,
      input: JSON.generate(
        "chat_id" => -100123,
        "text" => "x" * (PrismBot::Adapters::Telegram::BotApiClient::MAX_MESSAGE_CHARACTERS + 1),
        "idempotency_key" => "delivery-1"
      )
    )

    assert_equal 400, response.status
    assert_equal "bot.telegram.delivery.invalid", JSON.parse(response.body).dig("error", "code")
  end

  private

  def request(secret, body)
    Rack::MockRequest.new(@app).post(
      "/api/v1/delivery",
      "CONTENT_TYPE" => "application/json",
      "HTTP_X_PRISM_BOT_DELIVERY_SECRET" => secret,
      input: body
    )
  end
end
