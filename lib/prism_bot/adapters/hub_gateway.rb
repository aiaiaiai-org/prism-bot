# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    class HubGateway
      PAGE_LIMIT = 100
      MAX_PAGES = 100
      ACTOR_NOT_AUTHORIZED = "hub.actor.not_authorized".freeze

      include Ports::ActorOnboarder
      include Ports::ActorResolver
      include Ports::AlertSubscriptions
      include Ports::BotLifecycle
      include Ports::ChannelCatalog
      include Ports::PublicationPublisher
      include Ports::SurfaceBinding

      def initialize(client:)
        @client = client
      end

      def onboard_actor(provider:, provider_scope:, subject_id:)
        resolve_human_actor do
          @client.onboard_actor(
            provider: provider,
            provider_scope: provider_scope,
            subject_id: subject_id
          )
        end
      end

      def resolve_actor(provider:, provider_scope:, subject_id:)
        resolve_human_actor do
          @client.resolve_personal_actor(
            provider: provider,
            provider_scope: provider_scope,
            subject_id: subject_id
          )
        end
      end

      def status(provider:, provider_scope:, subject_id:)
        resolve_lifecycle_state(
          @client.get_personal_bot_status(
            provider: provider,
            provider_scope: provider_scope,
            subject_id: subject_id
          )
        )
      end

      def pause(provider:, provider_scope:, subject_id:)
        resolve_lifecycle_state(
          @client.pause_personal_bot(
            provider: provider,
            provider_scope: provider_scope,
            subject_id: subject_id
          )
        )
      end

      def resume(provider:, provider_scope:, subject_id:)
        resolve_lifecycle_state(
          @client.resume_personal_bot(
            provider: provider,
            provider_scope: provider_scope,
            subject_id: subject_id
          )
        )
      end

      def alert_status(provider:, provider_scope:, subject_id:)
        resolve_alert_subscription(
          @client.get_personal_alert_subscription(
            provider: provider,
            provider_scope: provider_scope,
            subject_id: subject_id
          )
        )
      end

      def save_alert(provider:, provider_scope:, subject_id:, subscription:)
        resolve_alert_subscription(
          @client.save_personal_alert_subscription(
            provider: provider,
            provider_scope: provider_scope,
            subject_id: subject_id,
            **subscription.to_h
          )
        )
      end

      def clear_alert(provider:, provider_scope:, subject_id:)
        @client.clear_personal_alert_subscription(
          provider: provider,
          provider_scope: provider_scope,
          subject_id: subject_id
        )
        nil
      end

      def bind_surface(provider:, provider_scope:, subject_id:, logical_channel:, chat_id:, message_thread_id: nil)
        evidence = {provider: provider, provider_scope: provider_scope, subject_id: subject_id}
        workspace_id = personal_workspace_id(@client.resolve_personal_actor(**evidence))
        # Reading the status makes sure the hub has this bot's instance in the person's workspace,
        # which the binding refers to when no instance id is given.
        @client.get_personal_bot_status(**evidence)
        @client.bind_telegram_surface(
          **evidence,
          workspace_id: workspace_id,
          logical_channel: logical_channel,
          chat_id: chat_id,
          message_thread_id: message_thread_id
        )
        nil
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

      private

      def resolve_alert_subscription(response)
        value = response.fetch("alert_subscription")
        return nil if value.nil?

        Domain::AlertSubscription.new(
          cell: value.fetch("cell"),
          categories: value.fetch("categories"),
          include_nearby: value.fetch("include_nearby")
        )
      rescue InputError, KeyError, TypeError
        raise TransportError.new(
          "bot.hub.alerts.response.invalid",
          "Prism Hub returned an invalid alert subscription response"
        )
      end

      def personal_workspace_id(response)
        workspace_id = response.fetch("actor").fetch("workspace_id")
        return workspace_id if workspace_id.is_a?(String) && !workspace_id.empty?

        raise KeyError, "workspace_id"
      rescue KeyError, TypeError
        raise TransportError.new(
          "bot.hub.actor.workspace.invalid",
          "Prism Hub returned an invalid personal workspace"
        )
      end

      def resolve_lifecycle_state(response)
        value = response.fetch("bot_instance")
        Domain::BotLifecycleState.new(status: value.fetch("status"))
      rescue InputError, KeyError, TypeError
        raise TransportError.new(
          "bot.hub.lifecycle.response.invalid",
          "Prism Hub returned an invalid bot lifecycle response"
        )
      end

      def resolve_human_actor
        response = yield
        actor = response.fetch("actor")
        identity = actor.fetch("identity")
        unless identity.fetch("type") == "person"
          raise TransportError.new(
            "bot.hub.actor.identity_type.invalid",
            "Prism Hub returned a non-human actor identity"
          )
        end
        unless actor.fetch("workspace_id").is_a?(String) && !actor.fetch("workspace_id").empty?
          raise TransportError.new(
            "bot.hub.actor.workspace.invalid",
            "Prism Hub returned an invalid personal workspace"
          )
        end

        Domain::HumanActor.new(
          canonical_id: identity.fetch("id"),
          role: actor.fetch("role")
        )
      rescue HubError => error
        return nil if error.http_status == 403 && error.code == ACTOR_NOT_AUTHORIZED

        raise
      rescue InputError, KeyError, TypeError
        raise TransportError.new(
          "bot.hub.actor.response.invalid",
          "Prism Hub returned an invalid actor response"
        )
      end
    end
  end
end
