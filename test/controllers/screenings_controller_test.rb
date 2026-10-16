require "test_helper"

class ScreeningsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @venue_a = create(:venue, name: "Grand Hall")
    @venue_b = create(:venue, name: "Old Cinema")

    @autumn = create(:film, title: "Autumn Light")
    @winter = create(:film, title: "Winter's Tale")

    @matching = create(:screening, film: @autumn, venue: @venue_a, starts_at: Time.utc(2027, 3, 12, 18, 0, 0))
    @other_venue = create(:screening, film: @autumn, venue: @venue_b, starts_at: Time.utc(2027, 3, 12, 20, 0, 0))
    @other_date = create(:screening, film: @autumn, venue: @venue_a, starts_at: Time.utc(2027, 3, 13, 18, 0, 0))
    @other_title = create(:screening, film: @winter, venue: @venue_a, starts_at: Time.utc(2027, 3, 12, 21, 0, 0))
  end

  test "lists all screenings with no filters" do
    get screenings_path

    assert_response :success
    assert_select "div[role=rowgroup] div[role=row]", count: 4
  end

  test "filters by venue" do
    get screenings_path, params: { venue_ids: [ @venue_a.id ] }

    assert_response :success
    assert_select "div[role=rowgroup] div[role=cell]", text: @matching.film.title
    assert_select "div[role=rowgroup] div[role=cell]", text: @venue_b.name, count: 0
  end

  test "filters by multiple venues" do
    get screenings_path, params: { venue_ids: [ @venue_a.id, @venue_b.id ] }

    assert_response :success
    assert_select "div[role=rowgroup] div[role=row]", count: 4
  end

  test "an empty venue selection behaves like no venue filter" do
    get screenings_path, params: { venue_ids: [ "" ] }

    assert_response :success
    assert_select "div[role=rowgroup] div[role=row]", count: 4
  end

  test "filters by date" do
    get screenings_path, params: { date: "2027-03-13" }

    assert_response :success
    assert_select "div[role=rowgroup] div[role=row]", count: 1
    assert_select "div[role=rowgroup] div[role=cell]", text: @other_date.film.title
  end

  test "filters by title search, case-insensitively" do
    get screenings_path, params: { q: "winter" }

    assert_response :success
    assert_select "div[role=rowgroup] div[role=row]", count: 1
    assert_select "div[role=rowgroup] div[role=cell]", text: @winter.title
  end

  test "paginates results and exposes a lazy-loading frame for the next page" do
    ScreeningsController::PER_PAGE.times do |n|
      create(:screening, film: @autumn, venue: @venue_a, starts_at: Time.utc(2027, 4, 1, 0, 0, 0) + n.minutes)
    end

    get screenings_path

    assert_response :success
    assert_select "turbo-frame#screenings_page_2[loading=lazy]"
  end

  test "last page has no further lazy-loading frame" do
    get screenings_path, params: { page: 1 }

    assert_response :success
    assert_select "turbo-frame#screenings_page_2", count: 0
  end

  test "defaults to sorting by start time ascending" do
    get screenings_path

    times = css_select("div[role=rowgroup] div[role=cell]:nth-child(3)").map(&:text)
    assert_equal times, times.sort
  end

  test "sorts by start time descending" do
    get screenings_path, params: { sort: "starts_at", direction: "desc" }

    titles = css_select("div[role=rowgroup] div[role=cell]:nth-child(1)").map(&:text)
    assert_equal [ @other_date, @other_title, @other_venue, @matching ].map { |s| s.film.title }, titles
  end

  test "sorts by film title ascending" do
    get screenings_path, params: { sort: "film" }

    titles = css_select("div[role=rowgroup] div[role=cell]:nth-child(1)").map(&:text)
    assert_equal [ "Autumn Light", "Autumn Light", "Autumn Light", "Winter's Tale" ], titles
  end

  test "sorts by venue name ascending" do
    get screenings_path, params: { sort: "venue" }

    venues = css_select("div[role=rowgroup] div[role=cell]:nth-child(2)").map(&:text)
    assert_equal [ "Grand Hall", "Grand Hall", "Grand Hall", "Old Cinema" ], venues
  end

  test "sorts by status" do
    create(:screening, film: @autumn, venue: @venue_a, starts_at: Time.utc(2027, 3, 12, 22, 0, 0), status: "cancelled")

    get screenings_path, params: { sort: "status" }

    statuses = css_select("div[role=rowgroup] div[role=cell]:nth-child(4)").map(&:text)
    assert_equal "Cancelled", statuses.first.strip
    assert_equal "Scheduled", statuses.last.strip
  end

  test "sort header links toggle direction and preserve filters" do
    get screenings_path, params: { venue_ids: [ @venue_a.id ], sort: "starts_at", direction: "asc" }

    assert_select "a[href=?]", screenings_path(venue_ids: [ @venue_a.id ], sort: "starts_at", direction: "desc")
  end
end
