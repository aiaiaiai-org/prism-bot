# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Client
    class Composition
      attr_reader :command_handlers, :state_handlers, :callback_handlers, :observers, :fallback, :state_store, :presenter,
        :open_commands

      # open_commands: names of command handlers any member of an allowed chat may use without a Hub
      # identity (see Channels::Telegram::ActorAuthorizer).
      def initialize(command_handlers:, fallback:, presenter:, state_handlers: {}, callback_handlers: {}, observers: [], state_store: nil,
        open_commands: [])
        @command_handlers = normalize_handlers(command_handlers, "command")
        @state_handlers = normalize_handlers(state_handlers, "state")
        @callback_handlers = normalize_handlers(callback_handlers, "callback")
        @observers = Array(observers).map { callable(_1, "observer") }.freeze
        @fallback = callable(fallback, "fallback")
        @presenter = validate_presenter!(presenter)
        @state_store = state_store || Adapters::NullInteractionStateStore.new
        validate_state_store!(@state_store)
        @open_commands = normalize_open_commands(open_commands)
        freeze
      end

      def with(
        command_handlers: {},
        state_handlers: {},
        callback_handlers: {},
        observers: [],
        fallback: @fallback,
        presenter: @presenter,
        state_store: @state_store,
        open_commands: []
      )
        self.class.new(
          command_handlers: @command_handlers.merge(command_handlers),
          state_handlers: @state_handlers.merge(state_handlers),
          callback_handlers: @callback_handlers.merge(callback_handlers),
          observers: @observers + Array(observers),
          fallback: fallback,
          presenter: presenter,
          state_store: state_store,
          open_commands: (@open_commands + Array(open_commands)).uniq
        )
      end

      private

      def normalize_open_commands(names)
        Array(names).map { String(_1).downcase }.uniq.each do |name|
          next if @command_handlers.key?(name)

          raise ArgumentError, "open command #{name} has no command handler"
        end.freeze
      end

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
