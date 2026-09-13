# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class ContextPolicy
        def initialize(allowed_chat_ids:)
          @allowed_chat_ids = normalize(allowed_chat_ids).freeze
        end

        def allowed?(update)
          @allowed_chat_ids.empty? || @allowed_chat_ids.include?(update.chat_id)
        end

        # True only when an operator enumerated the chats this bot serves.
        # An unrestricted policy vouches for nobody, so callers must not treat
        # an unlisted chat as trusted enough to answer.
        def restricted?
          !@allowed_chat_ids.empty?
        end

        private

        def normalize(values)
          Array(values).map { Integer(_1) }.uniq.sort
        rescue ArgumentError, TypeError
          raise ConfigurationError.new(
            "bot.telegram.context.invalid",
            "allowed Telegram chat ids must be integers"
          )
        end
      end
    end
  end
end
