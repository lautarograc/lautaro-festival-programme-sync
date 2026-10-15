class SyncRun < ApplicationRecord
  enum :status, { running: "running", succeeded: "succeeded", failed: "failed" }, default: "running"

  validates :started_at, presence: true
end
