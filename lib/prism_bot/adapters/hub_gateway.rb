# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    class HubGateway
      include Ports::ChannelCatalog
      include Ports::PublicationPublisher

      def initialize(client:)
        @client = client
      end

      def list
        @client.list_channels.fetch("channels")
      end

      def publish(publication:, idempotency_key:)
        @client.publish_publication(
          payload: publication.to_h,
          idempotency_key: idempotency_key
        )
      end
    end
  end
end
