# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismBot
  module Interfaces
    module HTTP
      class OutboundDeliveryEndpoint
        JSON_HEADERS = {
          "cache-control" => "no-store",
          "content-type" => "application/json; charset=utf-8"
        }.freeze
        DELIVERY_HEADER = "HTTP_X_PRISM_BOT_DELIVERY_SECRET".freeze

        def initialize(secret:, message_sender:, max_body_bytes:)
          @secret = secret
          @message_sender = message_sender
          @max_body_bytes = Integer(max_body_bytes)
          if @max_body_bytes <= 0
            raise ConfigurationError.new(
              "bot.delivery.max_body.invalid",
              "delivery body limit must be positive"
            )
          end
        end

        def call(environment)
          return response(404, "status" => "error", "error" => {"code" => "bot.route.not_found"}) unless
            environment.fetch("REQUEST_METHOD") == "POST" && environment.fetch("PATH_INFO") == "/api/v1/delivery"

          unless @secret.valid?(environment[DELIVERY_HEADER])
            return response(401, "status" => "error", "error" => {"code" => "bot.delivery.secret.invalid"})
          end
          unless media_type(environment["CONTENT_TYPE"]) == "application/json"
            return response(415, "status" => "error", "error" => {"code" => "bot.content_type.invalid"})
          end

          source = environment.fetch("rack.input").read(@max_body_bytes + 1)
          if source.bytesize > @max_body_bytes
            return response(413, "status" => "error", "error" => {"code" => "bot.payload.too_large"})
          end

          value = JSON.parse(source)
          result = @message_sender.deliver_message(
            chat_id: value.fetch("chat_id"),
            text: value.fetch("text"),
            idempotency_key: value.fetch("idempotency_key"),
            message_thread_id: value["message_thread_id"]
          )

          response(
            200,
            "status" => "ok",
            "delivery" => {
              "provider_message_id" => result.provider_message_id,
              "idempotency_key" => result.idempotency_key
            }
          )
        rescue JSON::ParserError
          response(400, "status" => "error", "error" => {"code" => "bot.json.invalid"})
        rescue KeyError, ArgumentError, TypeError
          response(400, "status" => "error", "error" => {"code" => "bot.delivery.request.invalid"})
        rescue DeliveryRateLimited => error
          response(
            429,
            "status" => "error",
            "error" => {
              "code" => error.code,
              "retry_after_seconds" => error.retry_after_seconds
            }
          )
        rescue MessageDeliveryError => error
          response(502, "status" => "error", "error" => {"code" => error.code})
        rescue KeyError
          response(400, "status" => "error", "error" => {"code" => "bot.request.invalid"})
        end

        private

        def media_type(value)
          String(value).split(";", 2).first.strip.downcase
        end

        def response(status, value)
          [status, JSON_HEADERS, [JSON.generate(value)]]
        end
      end
    end
  end
end
