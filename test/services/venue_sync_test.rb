require "test_helper"

class VenueSyncTest < ActiveSupport::TestCase
  test "creates a venue that doesn't exist yet" do
    payload = [
      { "id" => "VEN-01", "name" => "Grand Cinema", "address" => "12 Main Street", "capacity" => 320 }
    ]

    assert_difference "Venue.count", 1 do
      VenueSync.new(payload).call
    end

    venue = Venue.find_by(external_id: "VEN-01")
    assert_equal "Grand Cinema", venue.name
    assert_equal "12 Main Street", venue.address
    assert_equal 320, venue.capacity
  end
end
