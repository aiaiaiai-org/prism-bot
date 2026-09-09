# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  class Bootstrap
    def self.build(env:, client: nil, logger: Logger.new($stdout))
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
      bot_lifecycle = UseCases::ManageBotLifecycle.new(bot_lifecycle: hub_gateway)
      lifecycle = Channels::Telegram::LifecycleController.new(
        bot_lifecycle: bot_lifecycle
      )
      services = Client::Services.new(
        instance_id: configuration.instance_id,
        default_channel_ids: configuration.default_channel_ids,
        default_locale: configuration.default_locale,
        default_voice_profile: configuration.default_voice_profile,
        dispatch_policy: configuration.dispatch_policy,
        message_sender: message_sender,
        list_channels: UseCases::ListChannels.new(channel_catalog: hub_gateway),
        publish_publication: UseCases::PublishPublication.new(
          publication_publisher: hub_gateway
        ),
        bot_lifecycle: bot_lifecycle
      )
      client ||= Client::Default.new
      composition = client.call(services)
      unless composition.is_a?(Client::Composition)
        raise ConfigurationError.new(
          "bot.client.composition.invalid",
          "client must return a PrismBot::Client::Composition"
        )
      end
      command_router = Channels::Telegram::CommandRouter.new(
        handlers: composition.command_handlers,
        fallback: composition.fallback
      )
      interaction_router = Channels::Telegram::InteractionRouter.new(
        command_router: command_router,
        state_handlers: composition.state_handlers,
        state_store: composition.state_store,
        instance_id: configuration.instance_id
      )

      Channels::Telegram::WebhookApp.new(
        secret: Channels::Telegram::WebhookSecret.new(
          configuration.telegram_webhook_secret
        ),
        update_parser: Channels::Telegram::UpdateParser.new,
        context_policy: Channels::Telegram::ContextPolicy.new(
          allowed_chat_ids: configuration.allowed_chat_ids
        ),
        actor_authorizer: Channels::Telegram::ActorAuthorizer.new(
          resolve_actor: UseCases::ResolveActor.new(actor_resolver: hub_gateway),
          onboard_actor: UseCases::OnboardActor.new(actor_onboarder: hub_gateway)
        ),
        lifecycle_gate: Channels::Telegram::LifecycleGate.new(lifecycle: lifecycle),
        command_router: interaction_router,
        message_sender: message_sender,
        presenter: composition.presenter,
        logger: logger,
        max_body_bytes: configuration.max_webhook_bytes
      )
    end
  end
end
