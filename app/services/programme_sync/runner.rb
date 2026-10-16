module ProgrammeSync
  class Runner
    def initialize(generation: nil, fail_after: nil, slow: nil, client: Client.new)
      @generation = generation
      @fail_after = fail_after
      @slow = slow
      @client = client
    end

    def call
      sync_run = SyncRun.create!(status: :running, generation: @generation, started_at: Time.current)
      seen_external_ids = []

      begin
        @client.each_page(generation: @generation, fail_after: @fail_after, slow: @slow) do |screenings, page:, total_pages:|
          seen_external_ids.concat(ScreeningUpsert.new(screenings).call)
          sync_run.update!(pages_fetched: page, total_pages: total_pages, records_upserted: seen_external_ids.size)
        end

        removed = reconcile_removed_screenings(seen_external_ids)
        sync_run.update!(status: :succeeded, finished_at: Time.current, records_removed: removed)
      rescue StandardError => e
        sync_run.update!(status: :failed, finished_at: Time.current, error_message: "#{e.class}: #{e.message}")
        raise
      end

      sync_run
    end

    private

    def reconcile_removed_screenings(seen_external_ids)
      return 0 if seen_external_ids.empty?

      removed = Screening.where.not(external_id: seen_external_ids)
      count = removed.count
      removed.destroy_all
      count
    end
  end
end
