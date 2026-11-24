# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class TelegramChatMemberClientTest < Minitest::Test
  def client(transport, token: "424242:secret")
    PrismBot::Adapters::Telegram::ChatMemberClient.new(token: token, transport: transport)
  end

  def transport_for(result, status: 200)
    PrismBotTestSupport::FakeTransport.new(status: status, body: JSON.generate("ok" => status == 200, "result" => result))
  end

  def member(user_id, status)
    {"status" => status, "user" => {"id" => user_id}}
  end

  def test_reports_the_standing_of_the_person_asked_about
    transport = transport_for(member(7, "administrator"))
    membership = client(transport).chat_membership(chat_id: -1001, user_id: 7)

    assert_predicate membership, :administrator?
    assert_predicate membership, :present?
    assert_equal "https://api.telegram.org/bot424242:secret/getChatMember", transport.calls.fetch(0).fetch(:url)
    assert_equal({"chat_id" => -1001, "user_id" => 7}, JSON.parse(transport.calls.fetch(0).fetch(:body)))
  end

  def test_only_creators_and_administrators_count_as_administrators
    {"creator" => true, "administrator" => true, "member" => false, "restricted" => false, "left" => false, "kicked" => false}.each do |status, admin|
      membership = client(transport_for(member(7, status))).chat_membership(chat_id: -1, user_id: 7)

      assert_equal admin, membership.administrator?, status
    end
    refute_predicate client(transport_for(member(7, "left"))).chat_membership(chat_id: -1, user_id: 7), :present?
    assert_predicate client(transport_for(member(7, "restricted"))).chat_membership(chat_id: -1, user_id: 7), :present?
  end

  def test_own_membership_asks_about_the_bot_id_in_the_token
    transport = transport_for(member(424242, "administrator"))

    assert_predicate client(transport).own_membership(chat_id: -1001), :administrator?
    assert_equal 424242, JSON.parse(transport.calls.fetch(0).fetch(:body)).fetch("user_id")
  end

  def test_an_answer_about_someone_else_or_an_unknown_status_is_not_confirmation
    [member(8, "administrator"), member(7, "boss"), {"status" => "administrator"}, "administrator", nil].each do |result|
      error = assert_raises(PrismBot::MessageDeliveryError, result.inspect) do
        client(transport_for(result)).chat_membership(chat_id: -1, user_id: 7)
      end
      assert_equal "bot.telegram.chat_member.unconfirmed", error.code
    end
  end

  def test_a_refused_lookup_is_an_error_not_an_administrator
    transport = PrismBotTestSupport::FakeTransport.new(
      status: 400, body: JSON.generate("ok" => false, "description" => "Bad Request: user not found")
    )

    error = assert_raises(PrismBot::MessageDeliveryError) { client(transport).chat_membership(chat_id: -1, user_id: 7) }
    assert_equal "bot.telegram.chat_member.failed", error.code
    refute_includes error.message, "user not found"
  end

  def test_rejects_bad_requests_and_tokens
    transport = transport_for(member(7, "member"))

    assert_raises(PrismBot::InputError) { client(transport).chat_membership(chat_id: 0, user_id: 7) }
    assert_raises(PrismBot::InputError) { client(transport).chat_membership(chat_id: -1, user_id: 0) }
    assert_empty transport.calls
    assert_raises(PrismBot::ConfigurationError) { client(transport, token: "") }
  end

  def test_own_membership_needs_a_token_that_carries_the_bot_id
    transport = transport_for(member(1, "member"))

    ["no-colon", "abc:secret", ":secret"].each do |token|
      assert_raises(PrismBot::ConfigurationError, token) { client(transport, token: token).own_membership(chat_id: -1) }
    end
    assert_empty transport.calls
  end

  def test_membership_value_validates_its_fields
    assert_raises(PrismBot::InputError) { PrismBot::Domain::ChatMembership.new(chat_id: 0, user_id: 1, status: "member") }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::ChatMembership.new(chat_id: -1, user_id: 0, status: "member") }
    assert_raises(PrismBot::InputError) { PrismBot::Domain::ChatMembership.new(chat_id: -1, user_id: 1, status: "owner") }
  end
end
