# © 2026 aiaiaiai · aiaiaiai.org

require "securerandom"

module PrismBot
  module Adapters
    module Telegram
      class BotApiClient
        include Ports::MessageSender
        include Ports::OutboundDelivery

        MAX_MESSAGE_CHARACTERS = 4_096
        MAX_BUTTON_CHARACTERS = 64

        def initialize(token:, transport:)
          if !token.is_a?(String) || token.empty?
            raise ConfigurationError.new(
              "bot.telegram.token.invalid",
              "PRISM_BOT_TELEGRAM_TOKEN must not be empty"
            )
          end

          @api_base = "https://api.telegram.org/bot#{token}".freeze
          @endpoint = "#{@api_base}/sendMessage".freeze
          @transport = transport
        end

        def send_message(chat_id:, text:, message_thread_id: nil, location_request: nil)
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

        # Private delivery is a separate operation, never a fallback to send_message.
        def send_ephemeral_message(chat_id:, receiver_user_id:, text:, message_thread_id: nil, reply_markup: nil)
          target = ephemeral_target(chat_id:, receiver_user_id:, message_thread_id:)
          validate_text!(text, MAX_MESSAGE_CHARACTERS)
          target["text"] = text
          target["reply_markup"] = reply_markup if reply_markup
          target["link_preview_options"] = {"is_disabled" => true}
          result = telegram_request("sendMessage", target)
          verify_ephemeral!(result, chat_id:, receiver_user_id:, message_thread_id:)
        end

        def edit_ephemeral_message(chat_id:, receiver_user_id:, ephemeral_message_id:, text:, reply_markup: nil)
          ephemeral_target(chat_id:, receiver_user_id:, message_thread_id: nil)
          validate_text!(text, MAX_MESSAGE_CHARACTERS)
          unless positive_id?(ephemeral_message_id)
            raise InputError.new("bot.telegram.ephemeral.invalid", "Telegram ephemeral message ID is invalid")
          end

          fields = {
            "chat_id" => chat_id, "receiver_user_id" => receiver_user_id,
            "ephemeral_message_id" => ephemeral_message_id, "text" => text,
            "link_preview_options" => {"is_disabled" => true}
          }
          fields["reply_markup"] = reply_markup || {"inline_keyboard" => []}
          result = telegram_request("editEphemeralMessageText", fields)
          return true if result == true

          invalid_private_response!
        end

        def send_ephemeral_voice(chat_id:, receiver_user_id:, audio:, caption:, message_thread_id: nil)
          fields = ephemeral_target(chat_id:, receiver_user_id:, message_thread_id:)
          validate_text!(caption, 1024)
          fields["caption"] = caption
          fields["protect_content"] = true
          unless audio.is_a?(String) && audio.bytesize.between?(1, 10 * 1024 * 1024) &&
              audio.b.start_with?("OggS") && audio.b.byteslice(0, 128).include?("OpusHead")
            raise InputError.new("bot.telegram.voice.invalid", "Expected bounded OGG/Opus audio")
          end

          result = telegram_request("sendVoice", fields, audio: audio)
          verify_ephemeral!(result, chat_id:, receiver_user_id:, message_thread_id:)
          verify_voice!(result)
        end

        # Publishing is intentionally separate. The caller owns consent and scope.
        def send_public_voice(chat_id:, file_id:, caption:, message_thread_id: nil)
          fields = surface_target(chat_id:, message_thread_id:)
          validate_text!(caption, 1024)
          unless file_id.is_a?(String) && file_id.match?(/\A[A-Za-z0-9_-]{1,512}\z/)
            raise InputError.new("bot.telegram.voice.invalid", "Expected Telegram voice file ID")
          end

          fields["voice"] = file_id
          fields["caption"] = caption
          result = telegram_request("sendVoice", fields)
          unless result.is_a?(Hash) && result.dig("chat", "id") == chat_id &&
              result["message_thread_id"] == message_thread_id &&
              positive_id?(result["message_id"]) && !result["receiver_user"] && !result["ephemeral_message_id"]
            invalid_private_response!
          end

          verify_voice!(result)
        end

        private

        def positive_id?(value)
          value.is_a?(Integer) && value.positive?
        end

        def surface_target(chat_id:, message_thread_id:)
          unless chat_id.is_a?(Integer) && !chat_id.zero? && (message_thread_id.nil? || positive_id?(message_thread_id))
            raise InputError.new("bot.telegram.surface.invalid", "Telegram destination is invalid")
          end

          fields = {"chat_id" => chat_id}
          fields["message_thread_id"] = message_thread_id if message_thread_id
          fields
        end

        def ephemeral_target(chat_id:, receiver_user_id:, message_thread_id:)
          unless positive_id?(receiver_user_id)
            raise InputError.new("bot.telegram.ephemeral.invalid", "Telegram private recipient is required")
          end

          surface_target(chat_id:, message_thread_id:).merge(
            "ephemeral_message_parameters" => {"receiver_user_id" => receiver_user_id}
          )
        end

        def validate_text!(text, maximum)
          return if text.is_a?(String) && text.valid_encoding? && text.length.between?(1, maximum)

          raise InputError.new("bot.telegram.text.invalid", "Telegram text length is invalid")
        end

        def verify_ephemeral!(result, chat_id:, receiver_user_id:, message_thread_id:)
          if result.is_a?(Hash) && result["chat"].is_a?(Hash) && result["receiver_user"].is_a?(Hash) &&
              result.dig("chat", "id") == chat_id && result.dig("receiver_user", "id") == receiver_user_id &&
              result["message_thread_id"] == message_thread_id && positive_id?(result["ephemeral_message_id"])
            return result
          end

          invalid_private_response!
        end

        def verify_voice!(result)
          voice = result["voice"]
          return result if voice.is_a?(Hash) && voice["file_id"].is_a?(String) && !voice["file_id"].empty?

          invalid_private_response!
        end

        def invalid_private_response!
          raise MessageDeliveryError.new("bot.telegram.response.invalid", "Telegram returned an unexpected delivery result")
        end

        def telegram_request(method, fields, audio: nil)
          if audio
            boundary = "prism-#{SecureRandom.hex(24)}"
            body = +"".b
            fields.each do |key, value|
              serialized = value.is_a?(Hash) ? JSON.generate(value) : value.to_s
              body << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{key}\"\r\n\r\n".b
              body << serialized.b << "\r\n".b
            end
            body << "--#{boundary}\r\nContent-Disposition: form-data; name=\"voice\"; filename=\"voice.ogg\"\r\n".b
            body << "Content-Type: audio/ogg\r\n\r\n".b << audio.b << "\r\n--#{boundary}--\r\n".b
            content_type = "multipart/form-data; boundary=#{boundary}"
          else
            body = JSON.generate(fields)
            content_type = "application/json"
          end

          response = @transport.call(
            method: "POST", url: "#{@api_base}/#{method}",
            headers: {"accept" => "application/json", "content-type" => content_type}, body: body
          )
          value = parse_response(response.body)
          return value["result"] if response.status == 200 && value["ok"] == true

          raise_delivery_error(response.status, value)
        rescue TransportError => error
          raise error if error.is_a?(MessageDeliveryError)

          raise MessageDeliveryError.new("bot.telegram.unavailable", "Telegram is unavailable")
        end

        def perform_send(chat_id:, text:, message_thread_id: nil, disable_link_preview: false, location_request: nil)
          response = @transport.call(
            method: "POST",
            url: @endpoint,
            headers: {
              "accept" => "application/json",
              "content-type" => "application/json"
            },
            body: JSON.generate(payload(chat_id:, text:, message_thread_id:, disable_link_preview:, location_request:))
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
