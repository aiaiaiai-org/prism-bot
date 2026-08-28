# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class Command
        PATTERN = %r{\A/(?<name>[a-z][a-z0-9_]*)(?:@[a-z0-9_]+)?(?:\s+(?<arguments>.*))?\z}im

        attr_reader :name, :arguments

        def self.parse(text)
          match = PATTERN.match(String(text).strip)
          return nil unless match

          new(name: match[:name], arguments: match[:arguments].to_s)
        end

        def initialize(name:, arguments:)
          @name = String(name).downcase.freeze
          @arguments = String(arguments).freeze
          freeze
        end
      end
    end
  end
end
