# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    class NullInteractionStateStore
      include Ports::InteractionStateStore

      def load(key:)
        validate_key!(key)
        nil
      end

      def store(key:, state:)
        validate_key!(key)
        unless state.is_a?(Domain::InteractionState)
          raise ArgumentError, "state must be an InteractionState"
        end

        raise ConfigurationError.new(
          "bot.interaction.state_store.unavailable",
          "a client interaction state store is required for stateful flows"
        )
      end

      def delete(key:)
        validate_key!(key)
        nil
      end

      private

      def validate_key!(key)
        return if key.is_a?(Domain::InteractionKey)

        raise ArgumentError, "key must be an InteractionKey"
      end
    end
  end
end
