class ScreeningsController < ApplicationController
  PER_PAGE = 20

  SORT_COLUMNS = {
    "film" => "films.title",
    "venue" => "venues.name",
    "starts_at" => "screenings.starts_at",
    "status" => "screenings.status"
  }.freeze

  def index
    @venues = Venue.order(:name)

    @sort = SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : "starts_at"
    @direction = params[:direction] == "desc" ? "desc" : "asc"

    scope = filtered_screenings.order(Arel.sql("#{SORT_COLUMNS[@sort]} #{@direction}, screenings.id ASC"))

    @page = [ params[:page].to_i, 1 ].max
    @total = scope.count
    @screenings = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @has_more = @page * PER_PAGE < @total
  end

  private

  def filtered_screenings
    scope = Screening.includes(:film, :venue).joins(:film, :venue)
    scope = scope.where(venue_id: venue_ids) if venue_ids.present?
    scope = scope.where(starts_at: parsed_date.all_day) if parsed_date
    if params[:q].present?
      scope = scope.where("films.title ILIKE ?", "%#{Screening.sanitize_sql_like(params[:q])}%")
    end
    scope
  end

  def venue_ids
    Array(params[:venue_ids]).reject(&:blank?)
  end

  def parsed_date
    return nil if params[:date].blank?

    Date.parse(params[:date])
  rescue ArgumentError
    nil
  end
end
