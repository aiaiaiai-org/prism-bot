# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module BotLifecycle
      def status(provider:, provider_scope:, subject_id:)
        raise NotImplementedError
      end

      def pause(provider:, provider_scope:, subject_id:)
        raise NotImplementedError
      end

      def resume(provider:, provider_scope:, subject_id:)
        raise NotImplementedError
      end
    end
  end
end
