# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class PublishArguments
        Result = Struct.new(:channel_ids, :text, keyword_init: true)

        def initialize(default_channel_ids:)
          @default_channel_ids = normalize_channels(default_channel_ids).freeze
        end

        def parse(source)
          value = String(source).strip
          channels, text = value.start_with?("[") ? explicit(value) : [@default_channel_ids, value]
          if channels.empty?
            raise InputError.new(
              "bot.telegram.publish.channels.required",
              "select channels in brackets or configure default channels"
            )
          end
          if text.empty?
            raise InputError.new(
              "bot.telegram.publish.text.required",
              "publication text must not be empty"
            )
          end

          Result.new(channel_ids: channels, text: text.freeze).freeze
        end

        private

        def explicit(value)
          closing = value.index("]")
          unless closing
            raise InputError.new(
              "bot.telegram.publish.channels.invalid",
              "channel list must end with ]"
            )
          end

          channels = normalize_channels(value[1...closing].split(","))
          [channels, value[(closing + 1)..].to_s.strip]
        end

        def normalize_channels(values)
          channels = Array(values).map do |value|
            Domain::Publication.reference(String(value).strip, "channel_id")
          end
          if channels.uniq.length != channels.length
            raise InputError.new(
              "bot.telegram.publish.channels.duplicate",
              "selected channel ids must be unique"
            )
          end
          channels.freeze
        end
      end
    end
  end
end
