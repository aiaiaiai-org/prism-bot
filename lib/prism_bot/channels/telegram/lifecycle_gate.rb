# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class LifecycleGate
        BYPASS_COMMANDS = %w[start help status stop resume].freeze

        def initialize(lifecycle:)
          @lifecycle = lifecycle
        end

        def call(update)
          command = Command.parse(update.text)
          return nil if command && BYPASS_COMMANDS.include?(command.name)

          state = @lifecycle.status(update)
          state.active? ? nil : state
        end
      end
    end
  end
end
