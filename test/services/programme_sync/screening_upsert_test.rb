require "test_helper"

module ProgrammeSync
  class ScreeningUpsertTest < ActiveSupport::TestCase
    def screening_payload(id: "SCR-0001", film_id: "FILM-001", film_title: "The Silent Orchard",
                           venue_id: "VEN-01", venue_name: "Grand Cinema", status: "scheduled",
                           starts_at: "2027-03-10T18:00:00Z")
      {
        "id" => id,
        "starts_at" => starts_at,
        "status" => status,
        "film" => { "id" => film_id, "title" => film_title, "synopsis" => "...", "runtime" => 100, "year" => 2024 },
        "venue" => { "id" => venue_id, "name" => venue_name, "address" => "1 Main St", "capacity" => 200 }
      }
    end

    test "creates the film, venue and screening on first sight" do
      assert_difference ["Screening.count", "Film.count", "Venue.count"], 1 do
        ScreeningUpsert.new([screening_payload]).call
      end

      screening = Screening.find_by(external_id: "SCR-0001")
      assert_equal "FILM-001", screening.film.external_id
      assert_equal "VEN-01", screening.venue.external_id
    end

    test "is idempotent: running the same payload twice creates no duplicates" do
      2.times { ScreeningUpsert.new([screening_payload]).call }

      assert_equal 1, Screening.count
      assert_equal 1, Film.count
      assert_equal 1, Venue.count
    end

    test "updates a screening's venue without creating a duplicate when it moves" do
      ScreeningUpsert.new([screening_payload(venue_id: "VEN-01", venue_name: "Grand Cinema")]).call

      ScreeningUpsert.new([screening_payload(venue_id: "VEN-02", venue_name: "Riverside Cinema")]).call

      assert_equal 2, Venue.count
      screening = Screening.find_by(external_id: "SCR-0001")
      assert_equal "VEN-02", screening.venue.external_id
    end

    test "updates a film's title in place when retitled upstream (matches on external_id, not title)" do
      ScreeningUpsert.new([screening_payload(film_title: "Autumn in Trieste")]).call

      ScreeningUpsert.new([screening_payload(film_title: "Autumn in Trieste (Director's Cut)")]).call

      assert_equal 1, Film.count
      assert_equal "Autumn in Trieste (Director's Cut)", Film.find_by(external_id: "FILM-001").title
    end

    test "renames a venue in place when renamed upstream (matches on external_id, not name)" do
      ScreeningUpsert.new([screening_payload(venue_name: "City Gallery Screening Room")]).call

      ScreeningUpsert.new([screening_payload(venue_name: "City Gallery Auditorium")]).call

      assert_equal 1, Venue.count
      assert_equal "City Gallery Auditorium", Venue.find_by(external_id: "VEN-01").name
    end

    test "propagates a cancellation" do
      ScreeningUpsert.new([screening_payload(status: "scheduled")]).call

      ScreeningUpsert.new([screening_payload(status: "cancelled")]).call

      assert_predicate Screening.find_by(external_id: "SCR-0001"), :cancelled?
    end
  end
end
