# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    class HubGateway
      PAGE_LIMIT = 100
      MAX_PAGES = 100

      include Ports::ChannelCatalog
      include Ports::PublicationPublisher

      def initialize(client:)
        @client = client
      end

      def list
        channels = []
        cursor = nil
        seen = {}
        channel_ids = {}

        MAX_PAGES.times do
          page = HubChannelPage.new(
            @client.list_channels(limit: PAGE_LIMIT, cursor: cursor)
          )
          page.channels.each do |channel|
            id = channel.fetch("id")
            if channel_ids.key?(id)
              raise TransportError.new(
                "bot.hub.channels.duplicate",
                "Prism Hub returned a duplicate public channel id"
              )
            end
            channel_ids[id] = true
            channels << channel
          end
          return channels.freeze unless page.next_cursor

          if seen.key?(page.next_cursor)
            raise TransportError.new(
              "bot.hub.channels.cursor_repeated",
              "Prism Hub repeated a channel continuation cursor"
            )
          end
          seen[page.next_cursor] = true
          cursor = page.next_cursor
        end

        raise TransportError.new(
          "bot.hub.channels.page_limit_exceeded",
          "Prism Hub channel discovery exceeded the safe page limit"
        )
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
