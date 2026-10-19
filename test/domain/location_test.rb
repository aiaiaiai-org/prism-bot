# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../test_helper"

class LocationTest < Minitest::Test
  def test_holds_a_position_and_the_live_flag
    location = PrismBot::Domain::Location.new(latitude: "50.45", longitude: 30.52, live: true)

    assert_in_delta 50.45, location.latitude
    assert_in_delta 30.52, location.longitude
    assert location.live?
    assert location.frozen?
  end

  def test_rejects_non_finite_or_out_of_range_values
    [[91, 0], [0, 181], [Float::NAN, 0], [0, Float::INFINITY], [nil, 0], ["north", 0]].each do |lat, lon|
      assert_raises(PrismBot::InputError) { PrismBot::Domain::Location.new(latitude: lat, longitude: lon) }
    end
  end

  def test_the_live_flag_must_be_boolean
    assert_raises(PrismBot::InputError) do
      PrismBot::Domain::Location.new(latitude: 1, longitude: 1, live: "yes")
    end
  end
end
