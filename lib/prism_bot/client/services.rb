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
        @message_sender = service(message_sender, :send_message)
        @list_channels = service(list_channels, :call)
        @publish_publication = service(publish_publication, :call)
        @bot_lifecycle = lifecycle_service(bot_lifecycle)
        freeze
      end

      private

      def immutable_string(value)
        String(value).dup.freeze
      end

      def optional_string(value)
        value.nil? ? nil : immutable_string(value)
      end

      def service(value, method)
        return value if value.respond_to?(method)

        raise ArgumentError, "client service must respond to #{method}"
      end

      def lifecycle_service(value)
        required = %i[status pause resume]
        return value if required.all? { value.respond_to?(_1) }

        raise ArgumentError, "bot_lifecycle must implement status, pause, and resume"
      end
    end
  end
end
