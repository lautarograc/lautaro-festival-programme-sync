require "test_helper"

class ProgrammeSyncJobTest < ActiveSupport::TestCase
  # Stands in for the pooled Redis connection Sidekiq.redis yields, just
  # enough of SET/EVAL to exercise the job's lock/unlock logic without a
  # real Redis server.
  class FakeRedis
    def initialize
      @store = {}
    end

    def held?(key)
      @store.key?(key)
    end

    def call(*command)
      case command[0]
      when "SET"
        _, key, value, mode = command
        return nil if mode == "NX" && @store.key?(key)

        @store[key] = value
        "OK"
      when "EVAL"
        _, _script, _numkeys, key, token = command
        if @store[key] == token
          @store.delete(key)
          1
        else
          0
        end
      else
        raise "unsupported command: #{command.inspect}"
      end
    end
  end

  setup do
    @fake_redis = FakeRedis.new
  end

  test "skips the run when another sync already holds the lock" do
    @fake_redis.call("SET", ProgrammeSyncJob::LOCK_KEY, "someone-elses-token", "NX")

    with_fake_sidekiq_redis(@fake_redis) do
      assert_no_difference "SyncRun.count" do
        ProgrammeSyncJob.new.perform(1, nil, nil)
      end
    end

    assert @fake_redis.held?(ProgrammeSyncJob::LOCK_KEY), "the other run's lock should be left untouched"
  end

  test "acquires the lock, runs the sync, and releases the lock afterward" do
    with_fake_sidekiq_redis(@fake_redis) do
      with_client(MockApiStub.client) do
        ProgrammeSyncJob.new.perform(1, nil, nil)
      end
    end

    assert_predicate SyncRun.order(:started_at).last, :succeeded?
    assert_not @fake_redis.held?(ProgrammeSyncJob::LOCK_KEY)
  end

  test "releases the lock even when the sync fails" do
    with_fake_sidekiq_redis(@fake_redis) do
      with_client(MockApiStub.client(fail_after: 8)) do
        assert_raises(ProgrammeSync::Errors::ServerError) do
          ProgrammeSyncJob.new.perform(1, nil, nil)
        end
      end
    end

    assert_predicate SyncRun.order(:started_at).last, :failed?
    assert_not @fake_redis.held?(ProgrammeSyncJob::LOCK_KEY)
  end

  private

  def with_fake_sidekiq_redis(fake)
    original = Sidekiq.method(:redis)
    Sidekiq.define_singleton_method(:redis) { |&block| block.call(fake) }
    yield
  ensure
    Sidekiq.define_singleton_method(:redis, original)
  end

  def with_client(client)
    original = ProgrammeSync::Client.method(:new)
    ProgrammeSync::Client.define_singleton_method(:new) { |*, **| client }
    yield
  ensure
    ProgrammeSync::Client.define_singleton_method(:new, original)
  end
end
