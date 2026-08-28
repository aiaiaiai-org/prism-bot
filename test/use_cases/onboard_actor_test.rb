# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class OnboardActorTest < Minitest::Test
  include PrismBotTestSupport

  def test_delegates_provider_evidence_to_actor_onboarder
    onboarder = FakeActorOnboarder.new
    use_case = PrismBot::UseCases::OnboardActor.new(actor_onboarder: onboarder)

    actor = use_case.call(
      provider: "telegram",
      provider_scope: "global",
      subject_id: "123456789"
    )

    assert_equal "person:0x0sky", actor.canonical_ref
    assert_equal(
      [{provider: "telegram", provider_scope: "global", subject_id: "123456789"}],
      onboarder.requests
    )
  end
end
