class ProgrammeSyncJob < ApplicationJob
  queue_as :default
  LOCK_KEY = "programme_sync_job:lock"
  LOCK_TTL = 10.minutes

  RELEASE_SCRIPT = <<~LUA
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    else
      return 0
    end
  LUA

  def perform(generation = nil, fail_after = nil, slow = nil)
    token = SecureRandom.hex(16)

    unless acquire_lock(token)
      Rails.logger.info("[ProgrammeSyncJob] Skipping run: another sync is already in progress")
      return
    end

    begin
      ProgrammeSync::Runner.new(generation: generation, fail_after: fail_after, slow: slow).call
    ensure
      release_lock(token)
    end
  end

  private

  # SET ... NX only succeeds if nobody else holds the lock; EX bounds how long
  # a crashed worker (one that never reaches the ensure below) can hold it.
  def acquire_lock(token)
    Sidekiq.redis { |conn| conn.call("SET", LOCK_KEY, token, "NX", "EX", LOCK_TTL.to_i) } == "OK"
  end

  # Only clear the lock if it's still ours, so we never delete a later run's
  # lock after ours has already expired past LOCK_TTL.
  def release_lock(token)
    Sidekiq.redis { |conn| conn.call("EVAL", RELEASE_SCRIPT, "1", LOCK_KEY, token) }
  end
end
