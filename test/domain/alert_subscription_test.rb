# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class AlertSubscriptionTest < Minitest::Test
  CELL = "861e0d9a7ffffff".freeze

  def test_holds_a_cell_kinds_and_the_nearby_switch
    subscription = build

    assert_equal CELL, subscription.cell
    assert_equal %w[drone bomb], subscription.categories
    refute subscription.include_nearby?
    assert subscription.frozen?
    assert_equal({cell: CELL, categories: %w[drone bomb], include_nearby: false}, subscription.to_h)
  end

  def test_rejects_anything_that_is_not_a_resolution_six_cell
    ["", "861e0d9a7fffff", "861E0D9A7FFFFFF", "811e3ffffffffff", "lat,lon"].each do |cell|
      error = assert_raises(PrismBot::InputError) { build(cell: cell) }
      assert_equal "bot.alerts.cell.invalid", error.code
    end
  end

  def test_rejects_empty_repeated_or_unknown_kinds
    [[], %w[drone drone], %w[tank]].each do |categories|
      error = assert_raises(PrismBot::InputError) { build(categories: categories) }
      assert_equal "bot.alerts.categories.invalid", error.code
    end
  end

  def test_rejects_a_nearby_switch_that_is_not_a_boolean
    error = assert_raises(PrismBot::InputError) { build(include_nearby: "no") }
    assert_equal "bot.alerts.nearby.invalid", error.code
  end

  private

  def build(cell: CELL, categories: %w[drone bomb], include_nearby: false)
    PrismBot::Domain::AlertSubscription.new(
      cell: cell,
      categories: categories,
      include_nearby: include_nearby
    )
  end
end
