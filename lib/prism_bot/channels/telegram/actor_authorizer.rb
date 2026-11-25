# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class ActorAuthorizer
        PROVIDER = "telegram".freeze
        PROVIDER_SCOPE = "global".freeze
        ONBOARDING_COMMAND = "start".freeze

        # open_commands are commands a client opens to every member of an allowed chat: they need no
        # identity in Hub, so the person is not looked up. Their handler receives a guest actor
        # (role "member", canonical id "telegram:<user id>") that carries no Hub standing, and must
        # decide for itself what the person may do, for example from the chat's own member status.
        def initialize(resolve_actor:, onboard_actor:, open_commands: [])
          @resolve_actor = resolve_actor
          @onboard_actor = onboard_actor
          @open_commands = open_commands.map { String(_1).downcase }.freeze
        end

        def call(update)
          return nil unless update.user_id
          return nil if update.surface_context.chat_type == "channel"

          actor = open_command?(update) ? guest_actor(update) : actor_for(update)
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

        def open_command?(update)
          name = Command.parse(update.text)&.name
          !name.nil? && @open_commands.include?(name)
        end

        def guest_actor(update)
          Domain::HumanActor.new(canonical_id: "telegram:#{update.user_id}", role: "member")
        end

        def onboarding_command?(update)
          Command.parse(update.text)&.name == ONBOARDING_COMMAND
        end
      end
    end
  end
end
