# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class InteractionRouter
        SURFACE = "telegram"

        def initialize(command_router:, state_handlers:, state_store:, instance_id:)
          @command_router = command_router
          @state_handlers = normalize_handlers(state_handlers)
          @state_store = state_store
          @instance_id = String(instance_id).dup.freeze
        end

        def call(update)
          key = interaction_key(update)
          result = if Command.parse(update.text)
            @command_router.call(update)
          else
            route_non_command(update, key)
          end
          apply_transition(key, result)
        end

        private

        def route_non_command(update, key)
          state = @state_store.load(key: key)
          return @command_router.call(update) unless state

          handler = @state_handlers[state.name]
          unless handler
            raise ConfigurationError.new(
              "bot.interaction.state.unhandled",
              "no interaction handler is registered for #{state.name.inspect}"
            )
          end

          handler.call(update: update, state: state)
        end

        def interaction_key(update)
          Domain::InteractionKey.new(
            instance_id: @instance_id,
            surface: SURFACE,
            actor_ref: update.actor.canonical_ref
          )
        end

        def apply_transition(key, result)
          return result unless result.is_a?(Domain::InteractionTransition)

          case result.action
          when :keep
            nil
          when :set
            @state_store.store(key: key, state: result.state)
          when :clear
            @state_store.delete(key: key)
          end
          result
        end

        def normalize_handlers(handlers)
          handlers.to_h.each_with_object({}) do |(name, handler), result|
            state_name = Domain::InteractionState.new(name: name).name
            unless handler.respond_to?(:call)
              raise ArgumentError, "interaction state handler must respond to call"
            end
            result[state_name] = handler
          end.freeze
        end
      end
    end
  end
end
