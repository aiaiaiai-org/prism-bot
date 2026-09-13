# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class TelegramSurfaceContextTest < Minitest::Test
  include PrismBotTestSupport

  def test_parser_preserves_each_supported_chat_surface
    %w[private group supergroup channel].each do |type|
      payload = telegram_payload
      payload["message"]["chat"]["type"] = type
      update = parse(payload)

      assert_equal type, update.surface_context.kind
      assert_equal(-1001, update.surface_context.chat_id)
      assert_equal({chat_id: -1001}, update.reply_target)
    end
  end

  def test_forum_topic_carries_exact_reply_destination
    payload = telegram_payload
    payload["message"]["message_thread_id"] = 13
    payload["message"]["chat"]["title"] = "Engineering"
    update = parse(payload)

    assert_equal "forum_topic", update.surface_context.kind
    assert_equal "Engineering", update.surface_context.title
    assert_equal "telegram:-1001:13", update.surface_context.interaction_scope
    assert_equal({chat_id: -1001, message_thread_id: 13}, update.reply_target)
  end

  def test_private_chat_topics_are_preserved
    payload = telegram_payload
    payload["message"]["chat"]["type"] = "private"
    payload["message"]["message_thread_id"] = 5

    assert_equal 5, parse(payload).reply_target.fetch(:message_thread_id)
  end

  def test_scope_uses_ids_instead_of_mutable_titles
    first = surface(title: "Before")
    second = surface(title: "After")

    assert_equal first.interaction_scope, second.interaction_scope
    refute_equal first.interaction_scope, surface(message_thread_id: 14).interaction_scope
    refute_equal first.interaction_scope, surface(chat_id: -2002).interaction_scope
    refute_equal first.interaction_scope, surface(message_thread_id: nil).interaction_scope
  end

  def test_surface_is_immutable_and_does_not_retain_mutable_strings
    title = +"Engineering"
    context = surface(title: title)
    title.replace("Changed")

    assert_equal "Engineering", context.title
    assert context.frozen?
    assert context.title.frozen?
    assert context.reply_target.frozen?
  end

  def test_invalid_topic_identifiers_and_chat_types_are_rejected
    [0, -1, "13", 1.5, false].each do |identifier|
      assert_raises(PrismBot::InputError) { surface(message_thread_id: identifier) }
    end
    %w[group channel unknown].each do |type|
      assert_raises(PrismBot::InputError) { surface(chat_type: type) }
    end
    assert_raises(PrismBot::InputError) { surface(chat_type: "unsupported") }
    assert_raises(PrismBot::InputError) { surface(chat_id: 0) }
  end

  def test_update_cannot_claim_a_surface_from_another_chat
    assert_raises(PrismBot::InputError) do
      PrismBot::Channels::Telegram::Update.new(
        update_id: 42, chat_id: -2002, user_id: 7, text: "/context",
        surface_context: surface
      )
    end
  end

  def test_channel_posts_and_anonymous_senders_never_become_human_identity
    channel = telegram_payload
    channel["channel_post"] = channel.delete("message")
    channel["channel_post"]["chat"]["type"] = "channel"
    channel["channel_post"].delete("from")
    assert_nil parse(channel).user_id
    assert_equal "channel", parse(channel).surface_context.kind

    anonymous = telegram_payload
    anonymous["message"]["sender_chat"] = {"id" => -1001}
    assert_nil parse(anonymous).user_id

    bot = telegram_payload
    bot["message"]["from"]["is_bot"] = true
    assert_nil parse(bot).user_id
  end

  def test_edited_updates_and_non_text_messages_are_ignored
    payload = telegram_payload
    payload["edited_message"] = payload.delete("message")
    assert_nil parse(payload)

    payload = telegram_payload
    payload["message"].delete("text")
    assert_nil parse(payload)
  end

  private

  def parse(payload)
    PrismBot::Channels::Telegram::UpdateParser.new.call(payload)
  end

  def surface(**overrides)
    PrismBot::Channels::Telegram::SurfaceContext.new(
      **{chat_id: -1001, chat_type: "supergroup", message_thread_id: 13}.merge(overrides)
    )
  end
end
