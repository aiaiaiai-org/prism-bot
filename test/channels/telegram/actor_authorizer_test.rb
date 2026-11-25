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

  def test_an_open_command_needs_no_hub_identity_and_gets_a_guest_actor
    resolver = FakeActorResolver.new(denied_subject_ids: [999])
    onboarder = FakeActorOnboarder.new
    authorizer = build_authorizer(resolver: resolver, onboarder: onboarder, open_commands: %w[whisper start])

    ["/whisper", "/whisper@PrismBot 5", "/start", "/start@PrismBot"].each do |text|
      authorized = authorizer.call(telegram_update(text: text, user_id: 999))

      assert_instance_of PrismBot::Channels::Telegram::AuthorizedUpdate, authorized, text
      assert_equal "member", authorized.actor.role
      assert_equal "telegram:999", authorized.actor.canonical_id
      assert_equal 999, authorized.user_id
    end
    assert_empty resolver.requests, "Hub is not asked about people using open commands"
    assert_empty onboarder.requests, "an open /start does not onboard"
  end

  def test_commands_that_are_not_open_still_need_a_hub_identity
    resolver = FakeActorResolver.new(denied_subject_ids: [999])
    authorizer = build_authorizer(resolver: resolver, onboarder: FakeActorOnboarder.new, open_commands: %w[whisper])

    assert_nil authorizer.call(telegram_update(text: "/publish hi", user_id: 999))
    assert_nil authorizer.call(telegram_update(text: "whisper", user_id: 999)), "plain text is not a command"
    assert_nil authorizer.call(telegram_update(text: "/whisperer", user_id: 999)), "the name must match exactly"
    assert_equal 3, resolver.requests.length
  end

  def test_an_open_command_still_needs_a_person_and_never_works_in_a_channel
    authorizer = build_authorizer(resolver: FakeActorResolver.new, onboarder: FakeActorOnboarder.new, open_commands: %w[whisper])

    assert_nil authorizer.call(telegram_update(text: "/whisper", user_id: nil))
    surface = PrismBot::Channels::Telegram::SurfaceContext.new(chat_id: -1001, chat_type: "channel")
    channel_post = PrismBot::Channels::Telegram::Update.new(update_id: 1, chat_id: -1001, user_id: 7, text: "/whisper", surface_context: surface)
    assert_nil authorizer.call(channel_post)
  end

  private

  def build_authorizer(resolver:, onboarder:, open_commands: [])
    PrismBot::Channels::Telegram::ActorAuthorizer.new(
      resolve_actor: PrismBot::UseCases::ResolveActor.new(actor_resolver: resolver),
      onboard_actor: PrismBot::UseCases::OnboardActor.new(actor_onboarder: onboarder),
      open_commands: open_commands
    )
  end
end
