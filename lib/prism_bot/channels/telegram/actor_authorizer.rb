# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class ActorAuthorizer
        PROVIDER = "telegram".freeze
        PROVIDER_SCOPE = "global".freeze
        ONBOARDING_COMMAND = "start".freeze

        def initialize(resolve_actor:, onboard_actor:)
          @resolve_actor = resolve_actor
          @onboard_actor = onboard_actor
        end

        def call(update)
          actor = actor_for(update)
          return nil unless actor

          AuthorizedUpdate.new(update: update, actor: actor)
        end

        private

        def actor_for(update)
          use_case = onboarding_command?(update) ? @onboard_actor : @resolve_actor
          use_case.call(
            provider: PROVIDER,
            provider_scope: PROVIDER_SCOPE,
            subject_id: update.user_id.to_s
          )
        end

        def onboarding_command?(update)
          Command.parse(update.text)&.name == ONBOARDING_COMMAND
        end
      end
    end
  end
end
