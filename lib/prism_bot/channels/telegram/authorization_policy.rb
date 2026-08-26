# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class AuthorizationPolicy
        def initialize(allowed_user_ids:, allowed_chat_ids:)
          @allowed_user_ids = normalize(allowed_user_ids).freeze
          @allowed_chat_ids = normalize(allowed_chat_ids).freeze
          if @allowed_user_ids.empty? && @allowed_chat_ids.empty?
            raise ConfigurationError.new(
              "bot.telegram.authorization.empty",
              "at least one allowed Telegram user or chat id is required"
            )
          end
        end

        def allowed?(update)
          @allowed_user_ids.include?(update.user_id) || @allowed_chat_ids.include?(update.chat_id)
        end

        private

        def normalize(values)
          Array(values).map { Integer(_1) }.uniq.sort
        rescue ArgumentError, TypeError
          raise ConfigurationError.new(
            "bot.telegram.authorization.invalid",
            "allowed Telegram ids must be integers"
          )
        end
      end
    end
  end
end
