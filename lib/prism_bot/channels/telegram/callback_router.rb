# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      # Sends a button press to the handler registered for the route at the start of its data
      # ("route:payload"). A route nobody registered is ignored, not answered with a message: the
      # data is untrusted, and a stale or forged button must not produce output.
      class CallbackRouter
        def initialize(handlers: {})
          @handlers = handlers.to_h.transform_keys { String(_1).downcase }.freeze
        end

        def call(update)
          handler = @handlers[update.callback.route.downcase]
          return nil unless handler

          handler.call(update: update, arguments: update.callback.payload)
        end
      end
    end
  end
end
