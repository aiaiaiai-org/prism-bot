# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class ContextCard
        LABELS = {
          "private" => "Особистий чат",
          "group" => "Група",
          "supergroup" => "Супергрупа",
          "forum_topic" => "Гілка",
          "channel" => "Канал",
          "unknown" => "Невідомий тип чату"
        }.freeze

        UNSUPPORTED_CHANNEL = "Керування Prism у каналі поки не підтримується. Відкрий особистий чат із ботом або гілку групи.".freeze

        def call(surface)
          unless surface.is_a?(SurfaceContext)
            raise ArgumentError, "surface must be a Telegram::SurfaceContext"
          end

          title = surface.title.to_s.gsub(/[[:cntrl:]]/, " ").strip[0, 128]
          label = title.empty? ? LABELS.fetch(surface.kind) : title
          lines = ["Prism", "Контекст: #{label}", "Тип: #{LABELS.fetch(surface.kind)}", "Chat ID: #{surface.chat_id}"]
          lines << "Topic ID: #{surface.message_thread_id}" if surface.message_thread_id
          lines << "Прив’язка Hub: не перевірена"
          lines << UNSUPPORTED_CHANNEL if surface.chat_type == "channel"
          lines.join("\n")
        end
      end
    end
  end
end
