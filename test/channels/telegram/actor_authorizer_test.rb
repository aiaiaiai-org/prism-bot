# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class ActorAuthorizerTest < Minitest::Test
  include PrismBotTestSupport

  def test_maps_telegram_numeric_user_id_to_generic_provider_subject
    resolver = FakeActorResolver.new
    authorizer = PrismBot::Channels::Telegram::ActorAuthorizer.new(
      resolve_actor: PrismBot::UseCases::ResolveActor.new(actor_resolver: resolver)
    )

    authorized = authorizer.call(telegram_update(user_id: 123_456_789))

    assert_instance_of PrismBot::Channels::Telegram::AuthorizedUpdate, authorized
    assert_equal "person:0x0sky", authorized.actor.canonical_ref
    assert_equal 123_456_789, authorized.user_id
    assert_equal(
      [{provider: "telegram", provider_scope: "global", subject_id: "123456789"}],
      resolver.requests
    )
  end

  def test_returns_nil_when_hub_does_not_authorize_the_human_actor
    resolver = FakeActorResolver.new(denied_subject_ids: [999])
    authorizer = PrismBot::Channels::Telegram::ActorAuthorizer.new(
      resolve_actor: PrismBot::UseCases::ResolveActor.new(actor_resolver: resolver)
    )

    assert_nil authorizer.call(telegram_update(user_id: 999))
  end
end
