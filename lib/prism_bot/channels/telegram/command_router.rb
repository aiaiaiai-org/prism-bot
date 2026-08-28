# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class CommandRouter
        def initialize(handlers:, fallback:)
          @handlers = handlers.transform_keys { String(_1).downcase }.freeze
          @fallback = fallback
        end

        def call(update)
          command = Command.parse(update.text)
          return @fallback.call(update: update, arguments: update.text) unless command

          handler = @handlers.fetch(command.name, @fallback)
          handler.call(update: update, arguments: command.arguments)
        end
      end
    end
  end
end
