# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class ContextPolicyTest < Minitest::Test
  include PrismBotTestSupport

  def test_empty_policy_allows_any_chat_context
    policy = PrismBot::Channels::Telegram::ContextPolicy.new(allowed_chat_ids: [])

    assert policy.allowed?(telegram_update(chat_id: -1001))
    assert policy.allowed?(telegram_update(chat_id: 42))
  end

  def test_configured_policy_filters_only_by_chat
    policy = PrismBot::Channels::Telegram::ContextPolicy.new(
      allowed_chat_ids: [-2002]
    )

    assert policy.allowed?(telegram_update(user_id: 999, chat_id: -2002))
    refute policy.allowed?(telegram_update(user_id: 7, chat_id: -1001))
  end
end
