# Solution:

The solution involves creating a background job that syncs the festival programme from the external API to the local database. The job will handle pagination, update existing records, and ensure that no duplicates are created. It will also handle failures gracefully, ensuring that already retrieved records are not lost. It implements Rails-community defaults, adding a gem "sidekiq-scheduler" to schedule a sidekiq job without incurring the cost of a full cron job. The screenings index page is updated to use Hotwire for filtering, allowing for a more dynamic user experience without full page reloads.

I also reimplemented the test suite in minitest (from the project incluuded RSpec) for a variety of reasons, primarily personal preference but that preference is also based on an objective assessment I've made long ago; basically, Minitest is way better suited for modern Ruby parallelization and concurrency, which was a long suffered bottleneck I've had to deal in the CI/CD of pretty much all of my significant production Rails projects, so in every new project I start I aim to use Minitest as the default testing framework. (i also like the syntax way better than rspec)

Some decisions I made; the scheduled worker fires every 15 minutes as the requirements handled to me didn't specify a window. 15 minutes is reasonable to have fresh data without overusing the API. I also added a `SyncRun` model to keep track of the sync runs, their status, and any errors encountered. This allows for easy monitoring and debugging of the sync process. Beyond a single `records_upserted` total, `SyncRun` separately tracks `records_created`, `records_updated` and `records_skipped` (seen but unchanged), so a run's outcome can actually be read off afterwards rather than inferred.

I am assuming that the external API is the authoritative source of truth for the festival programme, and as such, I don't treat it as a "delta" feed, this means that the sync job can mark as "removed" records from the local database if they are no longer present in the API response. for idempotency, I also trust that the external_id present in the API response is unique and stable.

I'm commiting per-page in the transactions of the sync job, so that if a page fails, the already processed pages are not lost.

With more time, I would focus on adding telemetry and observability ops to the sync process, a more comprehensive test suite for the sync job (to better map edge cases like API failures, slow responses, timeouts, etc.), and I would also like to implement a better filtering UI for the screenings index page, like a segment-based filter or a in-between date range filter. I would also add a cache layer in-between sync runs.

# Festival Programme Sync — Take-Home

**Role:** Senior Rails / Hotwire Developer · **Time box:** 4 hours
**Stack:** Rails 8, Hotwire, PostgreSQL, Sidekiq, Tailwind (all in Docker)

## Context

You're joining a team that maintains a film festival's public website. It's a
Rails monolith that also acts as the editorial CMS, and it pulls programming data
from an external festival-management system over an API.

That external system is the source of truth for films, venues and screenings. Our
database holds a local copy so the site renders fast and stays up under load.
Today that copy is refreshed by a nightly script a colleague wrote in a hurry, and
it's been causing problems.

**Your job is to replace it.**

## What we've given you

A working Rails 8 app with `Film`, `Venue` and `Screening` models, a mock external
API at `/mock_api` that behaves like the real one including its failure modes, an
existing `VenueSync` service and its tests, a screenings index with a filter form,
and seed data.

### Running it

Everything runs in Docker. One step:

```bash
docker compose up --build
```

That starts Postgres, Redis, the Rails web server, a Tailwind watcher and Sidekiq,
and creates/migrates/seeds the database on first boot.

- App: <http://localhost:3000>
- Sidekiq dashboard: <http://localhost:3000/sidekiq>
- Postgres is exposed on host port **5544** (non-standard, so it won't collide)

Handy commands (see the `Makefile`):

```bash
make console   # rails console inside the web container
make test      # run the RSpec suite
make sh        # a shell in the web container
```

## What we'd like you to build

1. **A programme sync.** Pull screenings from `GET /mock_api/screenings` into our
   database. It's paginated, returns nested film and venue data, and behaves like a
   real third-party API: sometimes slow, sometimes failing partway through, and its
   records change between runs.

   Running it twice must not create duplicates. Running it after upstream data
   changes must update the local copy. If the API fails partway, records already
   retrieved shouldn't be lost. It should run on a schedule as a background job, and
   we should be able to tell afterwards whether a run succeeded and what it did.

2. **A filtered screenings list.** The index at `/screenings` has a filter form that
   reloads the whole page. Make it update just the results. Filters are date, venue,
   and a text search across titles. Keep it server-rendered; we're a Hotwire shop and
   aren't looking for a client-side rendering layer.

3. **A short README.** Half a page. What you'd do differently with more time, anything
   in the existing code you'd change and why, and any assumptions you made.

## Testing the mock API

| Parameter      | Effect                                                                                                     |
| -------------- | ---------------------------------------------------------------------------------------------------------- |
| `?page=2`      | Pagination, 25 records per page                                                                            |
| `?generation=2`| The dataset after upstream changes. Screenings have moved venue, some are cancelled, a film has been retitled, two screenings are new. |
| `?fail_after=8`| Returns 8 records, then a 500                                                                              |
| `?slow=true`   | Six-second delay                                                                                           |

Sync `generation=1`, then `generation=2`, and check the database is right. Then try
`generation=1&fail_after=8` and check nothing was lost.

## What we care about

- **Correctness under failure, ahead of feature completeness.** If you run short, a
  sync that handles the edge cases and a filter that doesn't quite work beats the
  reverse.
- Tests are expected — at least for the sync and the models. Tests for the view
  layer aren't. We're looking at how you test, not just that you did, so write
  your own; the repo doesn't hand you a test plan.

## Submitting

A private git repo with your commits. Please don't squash.
