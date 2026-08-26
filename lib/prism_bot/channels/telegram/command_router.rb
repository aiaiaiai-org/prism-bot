# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class CommandRouter
        COMMAND = %r{\A/(?<name>[a-z][a-z0-9_]*)(?:@[a-z0-9_]+)?(?:\s+(?<arguments>.*))?\z}im

        def initialize(handlers:, fallback:)
          @handlers = handlers.transform_keys { String(_1).downcase }.freeze
          @fallback = fallback
        end

        def call(update)
          match = COMMAND.match(update.text.strip)
          return @fallback.call(update: update, arguments: update.text) unless match

          handler = @handlers.fetch(match[:name].downcase, @fallback)
          handler.call(update: update, arguments: match[:arguments].to_s)
        end
      end
    end
  end
end
