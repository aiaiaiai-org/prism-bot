# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module UseCases
    class OnboardActor
      def initialize(actor_onboarder:)
        @actor_onboarder = actor_onboarder
      end

      def call(provider:, provider_scope:, subject_id:)
        @actor_onboarder.onboard_actor(
          provider: provider,
          provider_scope: provider_scope,
          subject_id: subject_id
        )
      end
    end
  end
end
