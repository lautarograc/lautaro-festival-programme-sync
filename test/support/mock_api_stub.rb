module MockApiStub
  def self.stubs(fail_after: nil)
    Faraday::Adapter::Test::Stubs.new.tap do |stubs|
      stubs.get(ProgrammeSync::Client::PATH) do |env|
        generation = env.params["generation"] || 1
        page       = [ env.params["page"].to_i, 1 ].max
        offset     = (page - 1) * MockApi::Dataset::PER_PAGE

        all = MockApi::Dataset.records(generation: generation)

        next [ 500, {}, { error: "Upstream festival system unavailable" }.to_json ] if fail_after && offset >= fail_after

        slice = all[offset, MockApi::Dataset::PER_PAGE] || []
        slice = slice.first([ fail_after - offset, 0 ].max) if fail_after

        body = {
          page: page,
          per_page: MockApi::Dataset::PER_PAGE,
          total_pages: (all.size.to_f / MockApi::Dataset::PER_PAGE).ceil,
          total_count: all.size,
          screenings: slice
        }

        [ 200, { "content-type" => "application/json" }, body.to_json ]
      end
    end
  end

  def self.client(fail_after: nil)
    ProgrammeSync::Client.new(adapter: [ :test, stubs(fail_after: fail_after) ])
  end
end
