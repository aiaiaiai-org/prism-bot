# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class ActorAuthorizerTest < Minitest::Test
  include PrismBotTestSupport

  def test_maps_ordinary_telegram_update_to_read_only_actor_resolution
    resolver = FakeActorResolver.new
    onboarder = FakeActorOnboarder.new
    authorizer = build_authorizer(resolver: resolver, onboarder: onboarder)

    authorized = authorizer.call(telegram_update(text: "/help", user_id: 123_456_789))

    assert_instance_of PrismBot::Channels::Telegram::AuthorizedUpdate, authorized
    assert_equal "person:0x0sky", authorized.actor.canonical_ref
    assert_equal 123_456_789, authorized.user_id
    assert_equal(
      [{provider: "telegram", provider_scope: "global", subject_id: "123456789"}],
      resolver.requests
    )
    assert_empty onboarder.requests
  end

  def test_uses_actor_onboarding_only_for_start_command
    resolver = FakeActorResolver.new
    onboarder = FakeActorOnboarder.new
    authorizer = build_authorizer(resolver: resolver, onboarder: onboarder)

    authorized = authorizer.call(
      telegram_update(text: "/start@PrismBot referral", user_id: 123_456_789)
    )

    assert_instance_of PrismBot::Channels::Telegram::AuthorizedUpdate, authorized
    assert_equal "person:0x0sky", authorized.actor.canonical_ref
    assert_equal(
      [{provider: "telegram", provider_scope: "global", subject_id: "123456789"}],
      onboarder.requests
    )
    assert_empty resolver.requests
  end

  def test_unknown_ordinary_actor_never_falls_back_to_onboarding
    resolver = FakeActorResolver.new(denied_subject_ids: [999])
    onboarder = FakeActorOnboarder.new
    authorizer = build_authorizer(resolver: resolver, onboarder: onboarder)

    assert_nil authorizer.call(telegram_update(text: "/publish hello", user_id: 999))
    assert_equal(
      [{provider: "telegram", provider_scope: "global", subject_id: "999"}],
      resolver.requests
    )
    assert_empty onboarder.requests
  end

  private

  def build_authorizer(resolver:, onboarder:)
    PrismBot::Channels::Telegram::ActorAuthorizer.new(
      resolve_actor: PrismBot::UseCases::ResolveActor.new(actor_resolver: resolver),
      onboard_actor: PrismBot::UseCases::OnboardActor.new(actor_onboarder: onboarder)
    )
  end
end
