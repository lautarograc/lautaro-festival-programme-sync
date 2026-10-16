class AddRecordBreakdownToSyncRuns < ActiveRecord::Migration[8.1]
  def change
    # records_upserted stays as the created+updated total
    add_column :sync_runs, :records_created, :integer, null: false, default: 0
    add_column :sync_runs, :records_updated, :integer, null: false, default: 0
    add_column :sync_runs, :records_skipped, :integer, null: false, default: 0
  end
end
