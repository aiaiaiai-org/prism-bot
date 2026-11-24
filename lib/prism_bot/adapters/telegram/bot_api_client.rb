# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    module Telegram
      class BotApiClient
        include Ports::MessageSender
        include Ports::OutboundDelivery
        include Ports::CallbackAnswerer
        include ApiSupport

        MAX_MESSAGE_CHARACTERS = 4_096
        MAX_BUTTON_CHARACTERS = 64
        MAX_CALLBACK_NOTICE_CHARACTERS = 200

        def initialize(token:, transport:)
          @endpoint = api_url(token, "sendMessage")
          @answer_endpoint = api_url(token, "answerCallbackQuery")
          @transport = transport
        end

        def send_message(chat_id:, text:, message_thread_id: nil, location_request: nil, ephemeral: nil)
          # This sender only posts publicly. A private reply must go through a sender that can
          # deliver it privately, so it is refused here rather than posted to the group.
          unless ephemeral.nil?
            raise InputError.new("bot.telegram.ephemeral.unsupported", "this sender cannot deliver privately")
          end
          if !message_thread_id.nil? && (!message_thread_id.is_a?(Integer) || !message_thread_id.positive?)
            raise InputError.new("bot.telegram.surface.thread.invalid", "Telegram topic is invalid")
          end

          perform_send(
            chat_id: chat_id,
            text: truncate(String(text)),
            message_thread_id: message_thread_id,
            location_request: validate_location_request!(location_request)
          )
          nil
        end

        def answer_callback_query(callback_query_id:, text: nil)
          unless callback_query_id.is_a?(String) && !callback_query_id.empty?
            raise InputError.new("bot.telegram.callback.id.invalid", "Telegram callback id is invalid")
          end
          unless text.nil? || (text.is_a?(String) && (1..MAX_CALLBACK_NOTICE_CHARACTERS).cover?(text.length))
            raise InputError.new("bot.telegram.callback.text.invalid", "callback notice is invalid")
          end

          payload = {"callback_query_id" => callback_query_id}
          payload["text"] = text if text
          request(@answer_endpoint, payload, code: "bot.telegram.callback.answer_failed",
            message: "Telegram rejected the callback answer")
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

        def perform_send(chat_id:, text:, message_thread_id: nil, disable_link_preview: false, location_request: nil)
          request(
            @endpoint,
            payload(chat_id:, text:, message_thread_id:, disable_link_preview:, location_request:)
          )
        end

        def request(url, body, code: "bot.telegram.send_failed", message: "Telegram rejected the response message")
          response = @transport.call(
            method: "POST",
            url: url,
            headers: {
              "accept" => "application/json",
              "content-type" => "application/json"
            },
            body: JSON.generate(body)
          )
          value = parse_response(response.body)
          return value if response.status == 200 && value["ok"] == true

          raise_delivery_error(response.status, value, code: code, message: message)
        rescue TransportError => error
          raise error if error.is_a?(MessageDeliveryError)

          raise MessageDeliveryError.new(
            "bot.telegram.unavailable",
            "Telegram is unavailable"
          )
        end

        def payload(chat_id:, text:, message_thread_id:, disable_link_preview:, location_request:)
          result = {"chat_id" => chat_id, "text" => text}
          result["message_thread_id"] = message_thread_id if message_thread_id
          if location_request
            result["reply_markup"] = {
              "keyboard" => [[{"text" => location_request, "request_location" => true}]],
              "resize_keyboard" => true,
              "one_time_keyboard" => true
            }
          end
          result["link_preview_options"] = {"is_disabled" => true} if disable_link_preview
          result
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

        def validate_location_request!(label)
          return nil if label.nil?
          return label if label.is_a?(String) && (1..MAX_BUTTON_CHARACTERS).cover?(label.length)

          raise InputError.new("bot.telegram.location_request.invalid", "location request label is invalid")
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
