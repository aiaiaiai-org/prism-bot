# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Client
    class Composition
      attr_reader :command_handlers, :state_handlers, :fallback, :state_store, :presenter

      def initialize(command_handlers:, fallback:, presenter:, state_handlers: {}, state_store: nil)
        @command_handlers = normalize_handlers(command_handlers, "command")
        @state_handlers = normalize_handlers(state_handlers, "state")
        @fallback = callable(fallback, "fallback")
        @presenter = validate_presenter!(presenter)
        @state_store = state_store || Adapters::NullInteractionStateStore.new
        validate_state_store!(@state_store)
        freeze
      end

      def with(
        command_handlers: {},
        state_handlers: {},
        fallback: @fallback,
        presenter: @presenter,
        state_store: @state_store
      )
        self.class.new(
          command_handlers: @command_handlers.merge(command_handlers),
          state_handlers: @state_handlers.merge(state_handlers),
          fallback: fallback,
          presenter: presenter,
          state_store: state_store
        )
      end

      private

      def normalize_handlers(handlers, kind)
        handlers.to_h.each_with_object({}) do |(name, handler), result|
          key = String(name).downcase.freeze
          if key.empty?
            raise ArgumentError, "#{kind} handler name must not be empty"
          end
          result[key] = callable(handler, "#{kind} handler")
        end.freeze
      end

      def callable(value, label)
        return value if value.respond_to?(:call)

        raise ArgumentError, "#{label} must respond to call"
      end

      def validate_presenter!(presenter)
        required = %i[error lifecycle_blocked]
        return presenter if required.all? { presenter.respond_to?(_1) }

        raise ArgumentError, "presenter must implement the Telegram presenter contract"
      end

      def validate_state_store!(store)
        required = %i[load store delete]
        return if required.all? { store.respond_to?(_1) }

        raise ArgumentError, "state_store must implement the interaction state store port"
      end
    end
  end
end
