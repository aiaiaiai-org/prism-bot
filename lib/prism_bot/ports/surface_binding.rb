# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module SurfaceBinding
      def bind_surface(provider:, provider_scope:, subject_id:, logical_channel:, chat_id:, message_thread_id: nil)
        raise NotImplementedError
      end
    end
  end
end
