# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    module Telegram
      class BotApiClient
        include Ports::MessageSender
        include Ports::OutboundDelivery

        MAX_MESSAGE_CHARACTERS = 4_096

        def initialize(token:, transport:)
          if !token.is_a?(String) || token.empty?
            raise ConfigurationError.new(
              "bot.telegram.token.invalid",
              "PRISM_BOT_TELEGRAM_TOKEN must not be empty"
            )
          end

          @endpoint = "https://api.telegram.org/bot#{token}/sendMessage".freeze
          @transport = transport
        end

        def send_message(chat_id:, text:)
          perform_send(chat_id: chat_id, text: truncate(String(text)))
          nil
        end

        def deliver_message(chat_id:, text:, idempotency_key:, message_thread_id: nil)
          validate_delivery!(chat_id:, text:, idempotency_key:, message_thread_id:)
          response = perform_send(
            chat_id: chat_id,
            text: text,
            message_thread_id: message_thread_id,
            disable_link_preview: true
          )
          Domain::DeliveryResult.new(
            provider_message_id: provider_message_id(response),
            idempotency_key: idempotency_key
          )
        end

        private

        def perform_send(chat_id:, text:, message_thread_id: nil, disable_link_preview: false)
          response = @transport.call(
            method: "POST",
            url: @endpoint,
            headers: {
              "accept" => "application/json",
              "content-type" => "application/json"
            },
            body: JSON.generate(payload(chat_id:, text:, message_thread_id:, disable_link_preview:))
          )
          value = parse_response(response.body)
          return value if response.status == 200 && value["ok"] == true

          raise_delivery_error(response.status, value)
        rescue TransportError => error
          raise error if error.is_a?(MessageDeliveryError)

          raise MessageDeliveryError.new(
            "bot.telegram.unavailable",
            "Telegram is unavailable"
          )
        end

        def payload(chat_id:, text:, message_thread_id:, disable_link_preview:)
          result = {"chat_id" => chat_id, "text" => text}
          result["message_thread_id"] = message_thread_id if message_thread_id
          result["link_preview_options"] = {"is_disabled" => true} if disable_link_preview
          result
        end

        def parse_response(body)
          value = JSON.parse(body)
          return value if value.is_a?(Hash)

          raise MessageDeliveryError.new(
            "bot.telegram.response.invalid",
            "Telegram returned an invalid response"
          )
        rescue JSON::ParserError
          raise MessageDeliveryError.new(
            "bot.telegram.response.invalid",
            "Telegram returned an invalid response"
          )
        end

        def raise_delivery_error(status, value)
          retry_after = value.dig("parameters", "retry_after") if value["parameters"].is_a?(Hash)
          if status == 429 && retry_after.is_a?(Integer) && retry_after.positive?
            raise DeliveryRateLimited.new(
              "bot.telegram.rate_limited",
              "Telegram rate limited delivery",
              retry_after_seconds: retry_after
            )
          end

          raise MessageDeliveryError.new(
            "bot.telegram.send_failed",
            "Telegram rejected the response message"
          )
        end

        def provider_message_id(value)
          result = value["result"]
          message_id = result["message_id"] if result.is_a?(Hash)
          return message_id if message_id.is_a?(Integer) && message_id.positive?

          raise MessageDeliveryError.new(
            "bot.telegram.response.invalid",
            "Telegram returned an invalid delivery result"
          )
        end

        def validate_delivery!(chat_id:, text:, idempotency_key:, message_thread_id:)
          valid_chat = chat_id.is_a?(Integer) || (chat_id.is_a?(String) && !chat_id.empty?)
          valid_text = text.is_a?(String) && (1..MAX_MESSAGE_CHARACTERS).cover?(text.length)
          valid_thread = message_thread_id.nil? || (message_thread_id.is_a?(Integer) && message_thread_id.positive?)
          valid_key = idempotency_key.is_a?(String) && idempotency_key.match?(/\A[^[:cntrl:]\s]{1,200}\z/)
          return if valid_chat && valid_text && valid_thread && valid_key

          raise InputError.new("bot.telegram.delivery.invalid", "outbound Telegram delivery is invalid")
        end

        def truncate(text)
          return text if text.length <= MAX_MESSAGE_CHARACTERS

          "#{text[0, MAX_MESSAGE_CHARACTERS - 1]}…"
        end
      end
    end
  end
end
