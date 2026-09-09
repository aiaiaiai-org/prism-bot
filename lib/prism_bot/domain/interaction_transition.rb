# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    class InteractionTransition
      ACTIONS = %i[keep set clear].freeze

      attr_reader :action, :state

      def self.keep
        new(action: :keep)
      end

      def self.set(state)
        new(action: :set, state: state)
      end

      def self.clear
        new(action: :clear)
      end

      def initialize(action:, state: nil)
        unless ACTIONS.include?(action)
          raise ArgumentError, "interaction transition action is invalid"
        end
        if action == :set && !state.is_a?(InteractionState)
          raise ArgumentError, "set transition requires an InteractionState"
        end
        if action != :set && !state.nil?
          raise ArgumentError, "only set transition may contain state"
        end

        @action = action
        @state = state
        freeze
      end
    end
  end
end
