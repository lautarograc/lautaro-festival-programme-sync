require "test_helper"

module ProgrammeSync
  class ClientTest < ActiveSupport::TestCase
    JSON_HEADERS = { "content-type" => "application/json" }.freeze

    test "walks every page until total_pages is reached" do
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get(Client::PATH) do |env|
        page = env.params["page"].to_i
        body = { page: page, total_pages: 3, screenings: [ { "id" => "SCR-#{page}" } ] }
        [ 200, JSON_HEADERS, body.to_json ]
      end
      client = Client.new(adapter: [ :test, stubs ])

      seen = []
      client.each_page { |screenings, page:, total_pages:| seen << [ page, total_pages, screenings ] }

      assert_equal [ 1, 2, 3 ], seen.map(&:first)
      assert_equal [ { "id" => "SCR-3" } ], seen.last[2]
    end

    test "retries a timed-out page with a wider window and succeeds" do
      attempts = 0
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get(Client::PATH) do
        attempts += 1
        raise Faraday::TimeoutError if attempts < 2

        [ 200, JSON_HEADERS, { page: 1, total_pages: 1, screenings: [] }.to_json ]
      end
      client = Client.new(adapter: [ :test, stubs ], base_timeout: 1, max_attempts: 3)

      client.each_page { |*| }

      assert_equal 2, attempts
    end

    test "raises a typed TimeoutError once every attempt is exhausted" do
      attempts = 0
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get(Client::PATH) do
        attempts += 1
        raise Faraday::TimeoutError
      end
      client = Client.new(adapter: [ :test, stubs ], base_timeout: 1, max_attempts: 3)

      assert_raises(Errors::TimeoutError) { client.each_page { |*| } }
      assert_equal 3, attempts
    end

    test "raises a typed ServerError on a 5xx without retrying" do
      attempts = 0
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get(Client::PATH) do
        attempts += 1
        [ 500, {}, { error: "boom" }.to_json ]
      end
      client = Client.new(adapter: [ :test, stubs ], max_attempts: 3)

      assert_raises(Errors::ServerError) { client.each_page { |*| } }
      assert_equal 1, attempts
    end

    test "stops fetching once a page fails, leaving earlier pages already yielded" do
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get(Client::PATH) do |env|
        page = env.params["page"].to_i
        next [ 500, {}, { error: "boom" }.to_json ] if page == 2

        [ 200, JSON_HEADERS, { page: page, total_pages: 3, screenings: [ { "id" => "SCR-#{page}" } ] }.to_json ]
      end
      client = Client.new(adapter: [ :test, stubs ])

      seen = []
      assert_raises(Errors::ServerError) do
        client.each_page { |screenings, page:, total_pages:| seen << page }
      end

      assert_equal [ 1 ], seen
    end
  end
end
