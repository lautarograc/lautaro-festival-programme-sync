class ProgrammeSyncJob < ApplicationJob
  queue_as :default

  def perform(generation = nil, fail_after = nil, slow = nil)
    ProgrammeSync::Runner.new(generation: generation, fail_after: fail_after, slow: slow).call
  end
end
