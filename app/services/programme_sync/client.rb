# frozen_string_literal: true

require "faraday"
module ProgrammeSync
  class Client
    PATH = "/mock_api/screenings"

    DEFAULT_BASE_TIMEOUT = 3
    DEFAULT_MAX_ATTEMPTS = 3
    BACKOFF_MULTIPLIER = 2

    def initialize(
      base_url: ENV.fetch("FESTIVAL_API_URL", "http://localhost:3000"),
      base_timeout: DEFAULT_BASE_TIMEOUT,
      max_attempts: DEFAULT_MAX_ATTEMPTS,
      adapter: Faraday.default_adapter
    )
      @base_url = base_url
      @base_timeout = base_timeout
      @max_attempts = max_attempts
      @adapter = adapter
    end

    # Raises a ProgrammeSync::Errors::Error if a page cant be retrieved.
    def each_page(generation: nil, fail_after: nil, slow: nil)
      page = 1

      loop do
        body = fetch_page(page: page, generation: generation, fail_after: fail_after, slow: slow)
        screenings  = body["screenings"]
        total_pages = body["total_pages"]
        raise Errors::UnexpectedResponseError, "Malformed response for page #{page}" unless screenings && total_pages

        yield screenings, page: page, total_pages: total_pages

        break unless page < total_pages

        page += 1
      end
    end

    private

    def fetch_page(page:, **query)
      attempt = 0

      begin
        attempt += 1
        window = @base_timeout * (BACKOFF_MULTIPLIER**(attempt - 1))
        response = connection(timeout: window).get(PATH, { page: page, **query }.compact)
        handle_response(response, page: page)
      rescue Faraday::TimeoutError
        raise Errors::TimeoutError, "Fetching page #{page} timed out after #{attempt} attempts" if attempt >= @max_attempts

        retry
      rescue Faraday::ConnectionFailed => e
        raise Errors::ConnectionError, "Connection failed fetching page #{page}: #{e.message}" if attempt >= @max_attempts

        retry
      end
    end

    def handle_response(response, page:)
      case response.status
      when 200
        response.body
      when 500..599
        raise Errors::ServerError, "Upstream returned #{response.status} fetching page #{page}"
      else
        raise Errors::UnexpectedResponseError, "Unexpected status #{response.status} fetching page #{page}"
      end
    end

    def connection(timeout:)
      Faraday.new(url: @base_url) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.options.timeout = timeout
        f.options.open_timeout = [timeout, @base_timeout].min
        f.adapter(*Array(@adapter))
      end
    end
  end
end
