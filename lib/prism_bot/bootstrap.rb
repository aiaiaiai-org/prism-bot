# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  class Bootstrap
    def self.build(env:, logger: Logger.new($stdout))
      configuration = Configuration.new(env)
      transport = Adapters::NetHttpTransport.new(
        allow_insecure_http: configuration.allow_insecure_http
      )
      hub_client = Generated::PrismHubV1Client.new(
        base_url: configuration.hub_base_url,
        token: configuration.hub_api_token,
        transport: transport
      )
      hub_gateway = Adapters::HubGateway.new(client: hub_client)
      message_sender = Adapters::Telegram::BotApiClient.new(
        token: configuration.telegram_token,
        transport: transport
      )
      presenter = Channels::Telegram::ResultPresenter.new
      handlers = handlers(
        configuration: configuration,
        hub_gateway: hub_gateway,
        message_sender: message_sender,
        presenter: presenter
      )
      router = Channels::Telegram::CommandRouter.new(
        handlers: handlers,
        fallback: Channels::Telegram::Handlers::Unknown.new(
          message_sender: message_sender,
          presenter: presenter
        )
      )

      Channels::Telegram::WebhookApp.new(
        secret: Channels::Telegram::WebhookSecret.new(
          configuration.telegram_webhook_secret
        ),
        update_parser: Channels::Telegram::UpdateParser.new,
        authorization_policy: Channels::Telegram::AuthorizationPolicy.new(
          allowed_user_ids: configuration.allowed_user_ids,
          allowed_chat_ids: configuration.allowed_chat_ids
        ),
        command_router: router,
        message_sender: message_sender,
        presenter: presenter,
        logger: logger,
        max_body_bytes: configuration.max_webhook_bytes
      )
    end

    def self.handlers(configuration:, hub_gateway:, message_sender:, presenter:)
      help = Channels::Telegram::Handlers::Help.new(
        message_sender: message_sender,
        presenter: presenter
      )
      {
        "help" => help,
        "start" => help,
        "channels" => Channels::Telegram::Handlers::Channels.new(
          list_channels: UseCases::ListChannels.new(channel_catalog: hub_gateway),
          message_sender: message_sender,
          presenter: presenter
        ),
        "publish" => Channels::Telegram::Handlers::Publish.new(
          arguments_parser: Channels::Telegram::PublishArguments.new(
            default_channel_ids: configuration.default_channel_ids
          ),
          publish_publication: UseCases::PublishPublication.new(
            publication_publisher: hub_gateway
          ),
          message_sender: message_sender,
          presenter: presenter,
          instance_id: configuration.instance_id,
          locale: configuration.default_locale,
          voice_profile: configuration.default_voice_profile,
          dispatch_policy: configuration.dispatch_policy
        )
      }.freeze
    end
    private_class_method :handlers
  end
end
