# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class WebhookApp
        JSON_HEADERS = {
          "cache-control" => "no-store",
          "content-type" => "application/json; charset=utf-8"
        }.freeze

        def initialize(
          secret:,
          update_parser:,
          authorization_policy:,
          command_router:,
          message_sender:,
          presenter:,
          logger:,
          max_body_bytes:
        )
          @secret = secret
          @update_parser = update_parser
          @authorization_policy = authorization_policy
          @command_router = command_router
          @message_sender = message_sender
          @presenter = presenter
          @logger = logger
          @max_body_bytes = Integer(max_body_bytes)
          if @max_body_bytes <= 0
            raise ConfigurationError.new(
              "bot.telegram.max_body.invalid",
              "PRISM_BOT_MAX_WEBHOOK_BYTES must be positive"
            )
          end
        end

        def call(environment)
          method = environment.fetch("REQUEST_METHOD")
          path = environment.fetch("PATH_INFO")
          if method == "GET" && path == "/healthz"
            return response(200, "status" => "ok", "service" => "prism-bot")
          end
          unless method == "POST" && path == "/telegram/webhook"
            return response(
              404,
              "status" => "error",
              "error" => {"code" => "bot.route.not_found"}
            )
          end

          webhook(environment)
        rescue KeyError
          response(400, "status" => "error", "error" => {"code" => "bot.request.invalid"})
        end

        private

        def webhook(environment)
          unless @secret.valid?(environment["HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN"])
            return response(401, "status" => "error", "error" => {"code" => "bot.telegram.secret.invalid"})
          end
          unless media_type(environment["CONTENT_TYPE"]) == "application/json"
            return response(415, "status" => "error", "error" => {"code" => "bot.content_type.invalid"})
          end

          source = environment.fetch("rack.input").read(@max_body_bytes + 1)
          if source.bytesize > @max_body_bytes
            return response(413, "status" => "error", "error" => {"code" => "bot.payload.too_large"})
          end

          value = JSON.parse(source)
          update = @update_parser.call(value)
          return accepted unless update

          unless @authorization_policy.allowed?(update)
            @logger.warn("telegram_webhook unauthorized_actor")
            return accepted
          end

          @command_router.call(update)
          accepted
        rescue JSON::ParserError
          response(400, "status" => "error", "error" => {"code" => "bot.json.invalid"})
        rescue MessageDeliveryError => error
          @logger.warn("telegram_webhook delivery_failed code=#{error.code}")
          accepted
        rescue Error => error
          @logger.warn("telegram_webhook handled_error code=#{error.code}")
          safely_notify(update, @presenter.error(error)) if update
          accepted
        rescue StandardError => error
          @logger.error("telegram_webhook unexpected_error class=#{error.class.name}")
          safely_notify(update, @presenter.error(error)) if update
          accepted
        end

        def safely_notify(update, text)
          @message_sender.send_message(chat_id: update.chat_id, text: text)
        rescue StandardError => error
          @logger.error("telegram_webhook notification_failed class=#{error.class.name}")
        end

        def media_type(value)
          String(value).split(";", 2).first.strip.downcase
        end

        def accepted
          response(200, "status" => "ok")
        end

        def response(status, value)
          [status, JSON_HEADERS, [JSON.generate(value)]]
        end
      end
    end
  end
end
