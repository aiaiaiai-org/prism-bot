# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class PublicationTest < Minitest::Test
  include PrismBotTestSupport

  def test_serializes_provider_neutral_multi_target_request
    value = PrismBotTestSupport.publication

    assert_predicate value, :frozen?
    assert_equal "require_all_valid", value.to_h.fetch("dispatch_policy")
    assert_equal "personal-threads", value.to_h.fetch("targets").first.fetch("channel_id")
    refute value.to_h.fetch("targets").first.key?("credential_ref")
    refute value.to_h.fetch("targets").first.key?("channel_ref")
  end

  def test_requires_target_selections_to_reference_declared_variants
    valid = PrismBotTestSupport.publication
    target = PrismBot::Domain::Publication::Target.new(
      id: "target-other",
      channel_id: "personal-instagram",
      selection: PrismBot::Domain::Publication::Selection.exact("missing-variant")
    )

    error = assert_raises(PrismBot::InputError) do
      PrismBot::Domain::Publication.new(
        dispatch_policy: "independent",
        variants: valid.variants,
        targets: [target]
      )
    end

    assert_equal "bot.publication.selection.unknown_variant", error.code
  end

  def test_rejects_empty_publication_body
    assert_raises(PrismBot::InputError) do
      PrismBot::Domain::Publication::Body.new
    end
  end
end
