require "test_helper"

module ProgrammeSync
  class RunnerTest < ActiveSupport::TestCase
    test "syncs generation 1, then generation 2, and leaves the database matching upstream" do
      Runner.new(generation: 1, client: MockApiStub.client).call

      assert_equal 60, Screening.count
      assert_equal "VEN-01", Screening.find_by(external_id: "SCR-0001").venue.external_id
      assert_predicate Screening.find_by(external_id: "SCR-0010"), :scheduled?
      assert_equal "Autumn in Trieste", Film.find_by(external_id: "FILM-005").title
      assert_equal "City Gallery Screening Room", Venue.find_by(external_id: "VEN-03").name

      run_2 = Runner.new(generation: 2, client: MockApiStub.client).call

      assert_predicate run_2, :succeeded?

      assert_equal 61, Screening.count

      assert_equal "VEN-06", Screening.find_by(external_id: "SCR-0001").venue.external_id
      assert_equal "VEN-05", Screening.find_by(external_id: "SCR-0002").venue.external_id

      %w[SCR-0010 SCR-0011 SCR-0012].each do |id|
        assert_predicate Screening.find_by(external_id: id), :cancelled?
      end

      assert_equal 12, Film.count
      assert_equal "Autumn in Trieste (Director's Cut)", Film.find_by(external_id: "FILM-005").title

      assert_equal 6, Venue.count
      assert_equal "City Gallery Auditorium", Venue.find_by(external_id: "VEN-03").name

      assert Screening.find_by(external_id: "SCR-0061").present?
      assert Screening.find_by(external_id: "SCR-0062").present?

      assert_nil Screening.find_by(external_id: "SCR-0060")
    end

    test "loses nothing already retrieved when the upstream fails partway through" do
      assert_raises(Errors::ServerError) do
        Runner.new(generation: 1, fail_after: 8, client: MockApiStub.client(fail_after: 8)).call
      end

      run = SyncRun.order(:started_at).last
      assert_predicate run, :failed?
      assert_equal 8, Screening.count
      assert_equal 8, run.records_upserted
      assert_equal 0, run.records_removed
    end

    test "does not reconcile deletions on a failed run" do
      Runner.new(generation: 2, client: MockApiStub.client).call
      assert_equal 61, Screening.count

      assert_raises(Errors::ServerError) do
        Runner.new(generation: 1, fail_after: 8, client: MockApiStub.client(fail_after: 8)).call
      end

      # The partial run only re-saw 8 of generation 1's screenings; the rest
      # of the generation-2 state must still be there untouched.
      assert_equal 61, Screening.count
    end

    test "records what happened on a SyncRun" do
      run = Runner.new(generation: 1, client: MockApiStub.client).call

      assert_predicate run, :succeeded?
      assert_equal 3, run.pages_fetched # 60 records / 25 per page, rounded up
      assert_equal 3, run.total_pages
      assert_equal 60, run.records_upserted
      assert run.finished_at.present?
    end
  end
end
