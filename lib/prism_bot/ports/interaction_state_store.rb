# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module InteractionStateStore
      def load(key:)
        raise NotImplementedError
      end

      def store(key:, state:)
        raise NotImplementedError
      end

      def delete(key:)
        raise NotImplementedError
      end
    end
  end
end
