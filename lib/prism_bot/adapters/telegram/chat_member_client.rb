# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    module Telegram
      # getChatMember. The answer is accepted only if it names the status of the person asked about.
      class ChatMemberClient
        include Ports::ChatMemberLookup
        include ApiSupport

        def initialize(token:, transport:)
          @endpoint = api_url(token, "getChatMember")
          # A bot token is "<bot user id>:<secret>"; only the public id is kept, for own_membership.
          @bot_user_id = Integer(token.split(":", 2).first, 10, exception: false)
          @transport = transport
        end

        def chat_membership(chat_id:, user_id:)
          unless chat_id.is_a?(Integer) && !chat_id.zero? && user_id.is_a?(Integer) && user_id.positive?
            raise InputError.new("bot.telegram.chat_member.invalid", "chat member request is invalid")
          end

          result = request("chat_id" => chat_id, "user_id" => user_id)["result"]
          status = result["status"] if result.is_a?(Hash)
          reported = result["user"]["id"] if result.is_a?(Hash) && result["user"].is_a?(Hash)
          unless Domain::ChatMembership::STATUSES.include?(status) && reported == user_id
            raise MessageDeliveryError.new(
              "bot.telegram.chat_member.unconfirmed",
              "Telegram did not confirm the chat member"
            )
          end

          Domain::ChatMembership.new(chat_id: chat_id, user_id: user_id, status: status)
        end

        def own_membership(chat_id:)
          unless @bot_user_id&.positive?
            raise ConfigurationError.new("bot.telegram.token.invalid", "PRISM_BOT_TELEGRAM_TOKEN is not a bot token")
          end

          chat_membership(chat_id: chat_id, user_id: @bot_user_id)
        end

        private

        def request(payload)
          response = @transport.call(
            method: "POST",
            url: @endpoint,
            headers: {"accept" => "application/json", "content-type" => "application/json"},
            body: JSON.generate(payload)
          )
          value = parse_response(response.body)
          return value if response.status == 200 && value["ok"] == true

          raise_delivery_error(response.status, value, code: "bot.telegram.chat_member.failed",
            message: "Telegram rejected the chat member lookup")
        rescue TransportError => error
          raise error if error.is_a?(MessageDeliveryError)

          raise MessageDeliveryError.new("bot.telegram.unavailable", "Telegram is unavailable")
        end
      end
    end
  end
end
