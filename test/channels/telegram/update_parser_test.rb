# © 2026 aiaiaiai · aiaiaiai.org

require_relative "../../test_helper"

class UpdateParserTest < Minitest::Test
  def test_parses_a_shared_position_as_an_update_without_text
    update = parse("message" => telegram_message("location" => {"latitude" => 50.45, "longitude" => 30.52}))

    assert_equal "", update.text
    assert_in_delta 50.45, update.location.latitude
    assert_in_delta 30.52, update.location.longitude
    refute update.location.live?
    assert_equal 7, update.user_id
  end

  def test_a_live_position_and_its_later_edits_are_live
    shared = parse("message" => telegram_message("location" => position(live_period: 3600)))
    moved = parse("edited_message" => telegram_message("location" => position(live_period: 3600)))

    assert shared.location.live?
    assert moved.location.live?
  end

  def test_an_edited_message_without_a_live_position_is_ignored
    assert_nil parse("edited_message" => telegram_message("text" => "edited"))
    assert_nil parse("edited_message" => telegram_message("location" => position))
  end

  def test_a_text_update_has_no_location
    update = parse("message" => telegram_message("text" => "/help"))

    assert_equal "/help", update.text
    assert_nil update.location
  end

  def test_other_updates_are_still_ignored
    assert_nil parse("message" => telegram_message("sticker" => {"file_id" => "x"}))
  end

  def test_rejects_a_position_outside_the_globe
    [{"latitude" => 200, "longitude" => 0}, {"latitude" => 0, "longitude" => -181}, {"latitude" => "x", "longitude" => 0}].each do |bad|
      assert_raises(PrismBot::InputError) { parse("message" => telegram_message("location" => bad)) }
    end
  end

  def test_rejects_a_position_missing_a_coordinate
    assert_raises(PrismBot::InputError) { parse("message" => telegram_message("location" => {"latitude" => 1})) }
  end

  private

  def parse(fields)
    PrismBot::Channels::Telegram::UpdateParser.new.call({"update_id" => 1}.merge(fields))
  end

  def position(live_period: nil)
    value = {"latitude" => 50.45, "longitude" => 30.52}
    value["live_period"] = live_period if live_period
    value
  end

  def telegram_message(fields)
    {
      "message_id" => 1,
      "chat" => {"id" => 42, "type" => "private"},
      "from" => {"id" => 7, "is_bot" => false}
    }.merge(fields)
  end
end
