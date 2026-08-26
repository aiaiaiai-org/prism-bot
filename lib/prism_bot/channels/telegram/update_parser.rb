# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class UpdateParser
        def call(value)
          unless value.is_a?(Hash)
            raise InputError.new("bot.telegram.update.invalid", "Telegram update must be a JSON object")
          end

          message = value["message"]
          return nil unless message.is_a?(Hash) && message["text"].is_a?(String)

          Update.new(
            update_id: value.fetch("update_id"),
            chat_id: message.fetch("chat").fetch("id"),
            user_id: message.fetch("from").fetch("id"),
            text: message.fetch("text")
          )
        rescue KeyError, ArgumentError, TypeError
          raise InputError.new(
            "bot.telegram.update.invalid",
            "Telegram text update is missing required identifiers"
          )
        end
      end
    end
  end
end
