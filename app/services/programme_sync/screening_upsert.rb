module ProgrammeSync
  class ScreeningUpsert
    # external_ids: every screening seen, regardless of whether it changed.
    # created/updated/skipped always sum to external_ids.size.
    Result = Struct.new(:external_ids, :created, :updated, :skipped, keyword_init: true)

    def initialize(screenings)
      @screenings = screenings
    end

    def call
      external_ids = []
      created = 0
      updated = 0
      skipped = 0

      ActiveRecord::Base.transaction do
        @screenings.each do |attrs|
          film = upsert_film(attrs.fetch("film"))
          venue = upsert_venue(attrs.fetch("venue"))
          screening, outcome = upsert_screening(attrs, film: film, venue: venue)

          external_ids << screening.external_id
          case outcome
          when :created then created += 1
          when :updated then updated += 1
          when :skipped then skipped += 1
          end
        end
      end

      Result.new(external_ids: external_ids, created: created, updated: updated, skipped: skipped)
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
      was_new = screening.new_record?

      screening.assign_attributes(
        film: film,
        venue: venue,
        starts_at: attrs.fetch("starts_at"),
        status: attrs.fetch("status")
      )

      outcome = was_new ? :created : (screening.changed? ? :updated : :skipped)
      screening.save! unless outcome == :skipped

      [ screening, outcome ]
    end
  end
end
