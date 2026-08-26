# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class ResultPresenter
        HELP = <<~TEXT.freeze
          Команди Prism Bot:
          /channels — доступні канали Hub
          /publish текст — допис у типові канали
          /publish [channel-a,channel-b] текст — допис у вибрані канали

          Перший зріз підтримує лише текстовий формат post. Stories і media з'являться після відповідних адаптерів Prism.
        TEXT

        def help
          HELP
        end

        def unknown
          "Невідома команда.\n\n#{HELP}"
        end

        def channels(values)
          items = Array(values)
          return "У Prism Hub ще не налаштовано жодного публічного каналу." if items.empty?

          lines = items.map do |channel|
            id = channel.fetch("id")
            label = channel.fetch("label")
            provider = channel.fetch("provider_id")
            capabilities = channel.fetch("capabilities")
            formats = capabilities.fetch("formats").join(", ")
            content = capabilities.fetch("media_kinds").dup
            content.unshift("text") if capabilities.fetch("text")
            "• #{id} — #{label} (#{provider}; формати: #{formats}; контент: #{content.join(', ')})"
          end
          (["Доступні канали:"] + lines).join("\n")
        rescue KeyError, TypeError
          raise TransportError.new(
            "bot.hub.channels.invalid",
            "Prism Hub returned invalid channel metadata"
          )
        end

        def published(response, target_count:)
          unless response.is_a?(Hash) && response["status"] == "ok"
            raise TransportError.new(
              "bot.hub.execution.invalid",
              "Prism Hub returned an invalid execution response"
            )
          end

          request_id = response.fetch("request_id", "unknown")
          outcomes = response.dig("result", "data", "outcomes")
          summary = outcome_summary(outcomes, target_count)
          "Prism завершив запит #{request_id}. #{summary}"
        end

        def error(error)
          case error
          when InputError
            "Команду не виконано: #{error.message}"
          when HubError
            reference = error.request_id ? " Запит: #{error.request_id}." : ""
            "Hub відхилив запит (#{error.code}).#{reference} Перевірте /channels або журнал Hub."
          when TransportError
            "Сервіс тимчасово недоступний (#{error.code}). Спробуйте пізніше."
          else
            "Сталася внутрішня помилка. Запит не буде повторено автоматично."
          end
        end

        private

        def outcome_summary(outcomes, target_count)
          return "Передано цілей: #{target_count}." unless outcomes.is_a?(Array) && outcomes.any?

          successful = outcomes.count { _1.is_a?(Hash) && _1["status"] == "ok" }
          "Успішних цілей: #{successful} із #{outcomes.length}."
        end
      end
    end
  end
end
