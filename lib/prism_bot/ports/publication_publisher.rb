# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module PublicationPublisher
      def publish(publication:, idempotency_key:)
        raise NotImplementedError
      end
    end
  end
end
