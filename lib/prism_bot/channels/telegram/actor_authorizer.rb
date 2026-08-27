# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class ActorAuthorizer
        PROVIDER = "telegram".freeze
        PROVIDER_SCOPE = "global".freeze

        def initialize(resolve_actor:)
          @resolve_actor = resolve_actor
        end

        def call(update)
          actor = @resolve_actor.call(
            provider: PROVIDER,
            provider_scope: PROVIDER_SCOPE,
            subject_id: update.user_id.to_s
          )
          return nil unless actor

          AuthorizedUpdate.new(update: update, actor: actor)
        end
      end
    end
  end
end
