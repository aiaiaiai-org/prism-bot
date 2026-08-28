# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class LifecycleController
        PROVIDER = "telegram".freeze
        PROVIDER_SCOPE = "global".freeze

        def initialize(bot_lifecycle:)
          @bot_lifecycle = bot_lifecycle
        end

        def status(update)
          call(:status, update)
        end

        def pause(update)
          call(:pause, update)
        end

        def resume(update)
          call(:resume, update)
        end

        private

        def call(operation, update)
          @bot_lifecycle.public_send(
            operation,
            provider: PROVIDER,
            provider_scope: PROVIDER_SCOPE,
            subject_id: update.user_id.to_s
          )
        end
      end
    end
  end
end
