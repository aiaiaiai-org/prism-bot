# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    module Telegram
      class BotApiClient
        include Ports::MessageSender

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
          response = @transport.call(
            method: "POST",
            url: @endpoint,
            headers: {
              "accept" => "application/json",
              "content-type" => "application/json"
            },
            body: JSON.generate(
              "chat_id" => chat_id,
              "text" => truncate(String(text))
            )
          )
          value = JSON.parse(response.body)
          return if response.status == 200 && value["ok"] == true

          raise MessageDeliveryError.new(
            "bot.telegram.send_failed",
            "Telegram rejected the response message"
          )
        rescue JSON::ParserError
          raise MessageDeliveryError.new(
            "bot.telegram.response.invalid",
            "Telegram returned an invalid response"
          )
        rescue TransportError => error
          raise error if error.is_a?(MessageDeliveryError)

          raise MessageDeliveryError.new(
            "bot.telegram.unavailable",
            "Telegram is unavailable"
          )
        end

        private

        def truncate(text)
          return text if text.length <= MAX_MESSAGE_CHARACTERS

          "#{text[0, MAX_MESSAGE_CHARACTERS - 1]}…"
        end
      end
    end
  end
end
