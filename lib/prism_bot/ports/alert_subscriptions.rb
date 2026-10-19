# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module AlertSubscriptions
      def alert_status(provider:, provider_scope:, subject_id:)
        raise NotImplementedError
      end

      def save_alert(provider:, provider_scope:, subject_id:, subscription:)
        raise NotImplementedError
      end

      def clear_alert(provider:, provider_scope:, subject_id:)
        raise NotImplementedError
      end
    end
  end
end
