# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class WebhookSecret
        PATTERN = /\A[A-Za-z0-9_-]{32,256}\z/

        def initialize(value)
          @value = String(value).dup.freeze
          return if PATTERN.match?(@value)

          raise ConfigurationError.new(
            "bot.telegram.webhook_secret.invalid",
            "Telegram webhook secret must contain 32-256 permitted characters"
          )
        end

        def valid?(candidate)
          candidate.is_a?(String) && Rack::Utils.secure_compare(candidate, @value)
        end
      end
    end
  end
end
