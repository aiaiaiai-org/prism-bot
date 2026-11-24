# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    module Telegram
      # Plumbing shared by the Bot API adapters: the endpoint for a token and the handling of a
      # response from Telegram.
      module ApiSupport
        API_ROOT = "https://api.telegram.org".freeze

        private

        def api_url(token, api_method)
          if !token.is_a?(String) || token.empty?
            raise ConfigurationError.new(
              "bot.telegram.token.invalid",
              "PRISM_BOT_TELEGRAM_TOKEN must not be empty"
            )
          end

          "#{API_ROOT}/bot#{token}/#{api_method}".freeze
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

        def raise_delivery_error(status, value, code: "bot.telegram.send_failed",
          message: "Telegram rejected the response message")
          retry_after = value.dig("parameters", "retry_after") if value["parameters"].is_a?(Hash)
          if status == 429 && retry_after.is_a?(Integer) && retry_after.positive?
            raise DeliveryRateLimited.new(
              "bot.telegram.rate_limited",
              "Telegram rate limited delivery",
              retry_after_seconds: retry_after
            )
          end

          raise MessageDeliveryError.new(code, message)
        end
      end
    end
  end
end
