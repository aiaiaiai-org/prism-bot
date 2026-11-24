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
          context_policy:,
          actor_authorizer:,
          lifecycle_gate:,
          command_router:,
          message_sender:,
          presenter:,
          logger:,
          max_body_bytes:,
          delivery_endpoint: nil,
          callback_answerer: nil,
          observation_parser: nil,
          observer: nil
        )
          @secret = secret
          @update_parser = update_parser
          @context_policy = context_policy
          @actor_authorizer = actor_authorizer
          @lifecycle_gate = lifecycle_gate
          @command_router = command_router
          @message_sender = message_sender
          @presenter = presenter
          @logger = logger
          @max_body_bytes = Integer(max_body_bytes)
          @delivery_endpoint = delivery_endpoint
          @callback_answerer = callback_answerer
          @observation_parser = observation_parser
          @observer = observer
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
          if @delivery_endpoint && method == "POST" && path == "/api/v1/delivery"
            return @delivery_endpoint.call(environment)
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
          observe(value)
          update = @update_parser.call(value)
          return accepted unless update

          unless @context_policy.allowed?(update)
            @logger.warn("telegram_webhook context_denied")
            return accepted
          end

          if update.surface_context.chat_type == "channel"
            if @context_policy.explicitly_allowed?(update) &&
                %w[start context].include?(Command.parse(update.text)&.name)
              safely_notify(update, ContextCard::UNSUPPORTED_CHANNEL)
            end
            return accepted
          end

          authorized_update = @actor_authorizer.call(update)
          unless authorized_update
            @logger.warn("telegram_webhook actor_not_authorized")
            return accepted
          end

          blocked_state = @lifecycle_gate.call(authorized_update)
          if blocked_state
            @logger.info("telegram_webhook lifecycle_blocked status=#{blocked_state.status}")
            safely_notify(authorized_update, @presenter.lifecycle_blocked(blocked_state))
            return accepted
          end

          @command_router.call(authorized_update)
          accepted
        rescue JSON::ParserError
          response(400, "status" => "error", "error" => {"code" => "bot.json.invalid"})
        rescue MessageDeliveryError => error
          @logger.warn("telegram_webhook delivery_failed code=#{error.code}")
          accepted
        rescue Error => error
          @logger.warn("telegram_webhook handled_error code=#{error.code}")
          safely_notify(authorized_update, @presenter.error(error)) if authorized_update
          accepted
        rescue StandardError => error
          @logger.error("telegram_webhook unexpected_error class=#{error.class.name}")
          safely_notify(authorized_update, @presenter.error(error)) if authorized_update
          accepted
        ensure
          answer_callback(update)
        end

        # Group content goes to observers before, and independently of, command handling: the same
        # message may also be a command, and a person who never onboarded is still observed. Only
        # allowed chats are observed, and nothing an observer does can change the response.
        def observe(value)
          return unless @observer && @observation_parser

          observation = @observation_parser.call(value)
          return unless observation && @context_policy.allowed?(observation)

          @observer.call(observation)
        rescue StandardError => error
          @logger.error("telegram_webhook observation_failed class=#{error.class.name}")
        end

        # Clears the progress bar on a pressed button, once the press has been handled or refused.
        # Answering last keeps the callback usable for a private reply until then. It carries no
        # text, and a failure to answer never changes how the update was handled.
        def answer_callback(update)
          return unless @callback_answerer && update&.callback

          @callback_answerer.answer_callback_query(callback_query_id: update.callback.id)
        rescue StandardError => error
          @logger.warn("telegram_webhook callback_answer_failed class=#{error.class.name}")
        end

        def safely_notify(update, text)
          @message_sender.send_message(**update.reply_target, text: text)
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
          # Rack 3 hands the headers hash to middleware that may add to it (Rack::ContentLength),
          # so every response gets its own mutable copy.
          [status, JSON_HEADERS.dup, [JSON.generate(value)]]
        end
      end
    end
  end
end
