# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module UseCases
    class ListChannels
      def initialize(channel_catalog:)
        @channel_catalog = channel_catalog
      end

      def call
        @channel_catalog.list
      end
    end
  end
end
