# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module ActorResolver
      def resolve_actor(provider:, provider_scope:, subject_id:)
        raise NotImplementedError
      end
    end
  end
end
