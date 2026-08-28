# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module UseCases
    class ManageBotLifecycle
      def initialize(bot_lifecycle:)
        @bot_lifecycle = bot_lifecycle
      end

      def status(**provider_evidence)
        @bot_lifecycle.status(**provider_evidence)
      end

      def pause(**provider_evidence)
        @bot_lifecycle.pause(**provider_evidence)
      end

      def resume(**provider_evidence)
        @bot_lifecycle.resume(**provider_evidence)
      end
    end
  end
end
