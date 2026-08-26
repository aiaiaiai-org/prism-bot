# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class AuthorizationPolicyTest < Minitest::Test
  include PrismBotTestSupport

  def test_allows_configured_user_or_chat
    policy = PrismBot::Channels::Telegram::AuthorizationPolicy.new(
      allowed_user_ids: [7],
      allowed_chat_ids: [-2002]
    )

    assert policy.allowed?(telegram_update(user_id: 7, chat_id: -1001))
    assert policy.allowed?(telegram_update(user_id: 8, chat_id: -2002))
    refute policy.allowed?(telegram_update(user_id: 8, chat_id: -1001))
  end

  def test_refuses_empty_policy
    assert_raises(PrismBot::ConfigurationError) do
      PrismBot::Channels::Telegram::AuthorizationPolicy.new(
        allowed_user_ids: [],
        allowed_chat_ids: []
      )
    end
  end
end
