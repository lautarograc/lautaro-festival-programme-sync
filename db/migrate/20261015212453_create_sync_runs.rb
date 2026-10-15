class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_runs do |t|
      t.string :status, null: false, default: "running"
      t.integer :generation
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :pages_fetched, null: false, default: 0
      t.integer :total_pages
      t.integer :records_upserted, null: false, default: 0
      t.integer :records_removed, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :sync_runs, :status
    add_index :sync_runs, :started_at
  end
end
