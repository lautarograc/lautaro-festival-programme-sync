module ProgrammeSync
  class ScreeningUpsert
    def initialize(screenings)
      @screenings = screenings
    end

    def call
      external_ids = []

      ActiveRecord::Base.transaction do
        @screenings.each do |attrs|
          film      = upsert_film(attrs.fetch("film"))
          venue     = upsert_venue(attrs.fetch("venue"))
          screening = upsert_screening(attrs, film: film, venue: venue)
          external_ids << screening.external_id
        end
      end

      external_ids
    end

    private

    def upsert_film(attrs)
      film = Film.find_or_initialize_by(external_id: attrs.fetch("id"))
      film.assign_attributes(
        title: attrs["title"],
        synopsis: attrs["synopsis"],
        runtime: attrs["runtime"],
        year: attrs["year"]
      )
      film.save! if film.new_record? || film.changed?
      film
    end

    def upsert_venue(attrs)
      venue = Venue.find_or_initialize_by(external_id: attrs.fetch("id"))
      venue.assign_attributes(
        name: attrs["name"],
        address: attrs["address"],
        capacity: attrs["capacity"]
      )
      venue.save! if venue.new_record? || venue.changed?
      venue
    end

    def upsert_screening(attrs, film:, venue:)
      screening = Screening.find_or_initialize_by(external_id: attrs.fetch("id"))
      screening.assign_attributes(
        film: film,
        venue: venue,
        starts_at: attrs.fetch("starts_at"),
        status: attrs.fetch("status")
      )
      screening.save! if screening.new_record? || screening.changed?
      screening
    end
  end
end
