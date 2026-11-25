# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class LifecycleGate
        BYPASS_COMMANDS = %w[start help context status stop resume].freeze

        # Open commands (see ActorAuthorizer) belong to no Hub actor, so there is no bot lifecycle to consult.
        def initialize(lifecycle:, open_commands: [])
          @lifecycle = lifecycle
          @open_commands = open_commands.map { String(_1).downcase }.freeze
        end

        def call(update)
          command = Command.parse(update.text)
          return nil if command && (BYPASS_COMMANDS.include?(command.name) || @open_commands.include?(command.name))

          state = @lifecycle.status(update)
          state.active? ? nil : state
        end
      end
    end
  end
end
