# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Client
    class Services
      attr_reader :instance_id,
        :default_channel_ids,
        :default_locale,
        :default_voice_profile,
        :dispatch_policy,
        :message_sender,
        :list_channels,
        :publish_publication,
        :bot_lifecycle

      def initialize(
        instance_id:,
        default_channel_ids:,
        default_locale:,
        default_voice_profile:,
        dispatch_policy:,
        message_sender:,
        list_channels:,
        publish_publication:,
        bot_lifecycle:
      )
        @instance_id = immutable_string(instance_id)
        @default_channel_ids = default_channel_ids.map { immutable_string(_1) }.freeze
        @default_locale = immutable_string(default_locale)
        @default_voice_profile = optional_string(default_voice_profile)
        @dispatch_policy = immutable_string(dispatch_policy)
        @message_sender = callable_service(message_sender, :send_message)
        @list_channels = callable_service(list_channels, :call)
        @publish_publication = callable_service(publish_publication, :call)
        @bot_lifecycle = callable_service(bot_lifecycle, :call)
        freeze
      end

      private

      def immutable_string(value)
        String(value).dup.freeze
      end

      def optional_string(value)
        value.nil? ? nil : immutable_string(value)
      end

      def callable_service(value, method)
        return value if value.respond_to?(method)

        raise ArgumentError, "client service must respond to #{method}"
      end
    end
  end
end
