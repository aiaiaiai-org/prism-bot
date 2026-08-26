# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    class HubChannelPage
      FORMATS = %w[post story short_video poll].freeze
      MEDIA_KINDS = %w[image video audio document].freeze

      attr_reader :channels, :next_cursor

      def initialize(response)
        unless response.is_a?(Hash) && response["channels"].is_a?(Array) && response["page"].is_a?(Hash)
          invalid!
        end

        @channels = response.fetch("channels").map { |value| channel(value) }.freeze
        @next_cursor = cursor(response.fetch("page")["next_cursor"])
        freeze
      rescue KeyError, TypeError
        invalid!
      end

      private

      def channel(value)
        capabilities = value.fetch("capabilities")
        formats = enum_values(capabilities.fetch("formats"), FORMATS)
        media_kinds = enum_values(capabilities.fetch("media_kinds"), MEDIA_KINDS, allow_empty: true)
        text = capabilities.fetch("text")
        unless [true, false].include?(text) && (text || media_kinds.any?)
          invalid!
        end

        {
          "id" => required_string(value.fetch("id")),
          "label" => required_string(value.fetch("label")),
          "provider_id" => required_string(value.fetch("provider_id")),
          "capabilities" => {
            "formats" => formats,
            "text" => text,
            "media_kinds" => media_kinds
          }.freeze
        }.freeze
      rescue NoMethodError
        invalid!
      end

      def enum_values(values, allowed, allow_empty: false)
        unless values.is_a?(Array) && values.all? { |value| value.is_a?(String) }
          invalid!
        end

        normalized = values.uniq.sort
        invalid! if (!allow_empty && normalized.empty?) || (normalized - allowed).any?
        normalized.map!(&:freeze)
        normalized.freeze
      end

      def required_string(value)
        return value.dup.freeze if value.is_a?(String) && !value.empty?

        invalid!
      end

      def cursor(value)
        return nil if value.nil?
        return value.dup.freeze if value.is_a?(String) && !value.empty?

        invalid!
      end

      def invalid!
        raise TransportError.new(
          "bot.hub.channels.invalid",
          "Prism Hub returned invalid channel discovery metadata"
        )
      end
    end
  end
end
