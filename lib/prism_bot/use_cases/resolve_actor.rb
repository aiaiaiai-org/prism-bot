# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module UseCases
    class ResolveActor
      def initialize(actor_resolver:)
        @actor_resolver = actor_resolver
      end

      def call(provider:, provider_scope:, subject_id:)
        @actor_resolver.resolve_actor(
          provider: provider,
          provider_scope: provider_scope,
          subject_id: subject_id
        )
      end
    end
  end
end
