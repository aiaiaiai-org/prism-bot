# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    # Lets a client product call a Hub operation of its own on behalf of one person, without
    # prism-bot knowing what the operation means. The Hub resolves the person from the evidence.
    module PersonalHubCall
      def personal_call(path:, provider:, provider_scope:, subject_id:, fields: {})
        raise NotImplementedError
      end
    end
  end
end
