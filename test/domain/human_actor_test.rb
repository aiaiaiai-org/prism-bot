# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class HumanActorTest < Minitest::Test
  def test_preserves_provider_independent_human_identity
    actor = PrismBot::Domain::HumanActor.new(
      canonical_id: "0x0sky",
      role: "owner"
    )

    assert_equal "person", actor.canonical_type
    assert_equal "0x0sky", actor.canonical_id
    assert_equal "person:0x0sky", actor.canonical_ref
    assert_equal "owner", actor.role
    assert actor.frozen?
  end

  def test_rejects_unknown_workspace_role
    error = assert_raises(PrismBot::InputError) do
      PrismBot::Domain::HumanActor.new(canonical_id: "0x0sky", role: "publisher")
    end

    assert_equal "bot.actor.role.invalid", error.code
  end
end
