# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Client
    class Default
      def initialize(presenter: Channels::Telegram::ResultPresenter.new)
        @presenter = presenter
      end

      def call(services)
        lifecycle = Channels::Telegram::LifecycleController.new(
          bot_lifecycle: services.bot_lifecycle
        )
        Composition.new(
          command_handlers: command_handlers(services, lifecycle),
          fallback: Channels::Telegram::Handlers::Unknown.new(
            message_sender: services.message_sender,
            presenter: @presenter
          )
        )
      end

      private

      def command_handlers(services, lifecycle)
        {
          "help" => Channels::Telegram::Handlers::Help.new(
            message_sender: services.message_sender,
            presenter: @presenter
          ),
          "start" => Channels::Telegram::Handlers::Start.new(
            message_sender: services.message_sender,
            presenter: @presenter
          ),
          "status" => lifecycle_handler(:status, lifecycle, services),
          "stop" => lifecycle_handler(:pause, lifecycle, services),
          "resume" => lifecycle_handler(:resume, lifecycle, services),
          "channels" => Channels::Telegram::Handlers::Channels.new(
            list_channels: services.list_channels,
            message_sender: services.message_sender,
            presenter: @presenter
          ),
          "publish" => publish_handler(services)
        }.freeze
      end

      def lifecycle_handler(operation, lifecycle, services)
        Channels::Telegram::Handlers::Lifecycle.new(
          operation: operation,
          lifecycle: lifecycle,
          message_sender: services.message_sender,
          presenter: @presenter
        )
      end

      def publish_handler(services)
        Channels::Telegram::Handlers::Publish.new(
          arguments_parser: Channels::Telegram::PublishArguments.new(
            default_channel_ids: services.default_channel_ids
          ),
          publish_publication: services.publish_publication,
          message_sender: services.message_sender,
          presenter: @presenter,
          instance_id: services.instance_id,
          locale: services.default_locale,
          voice_profile: services.default_voice_profile,
          dispatch_policy: services.dispatch_policy
        )
      end
    end
  end
end
