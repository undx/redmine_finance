class CreateDeliverablesTrackers < ActiveRecord::Migration
  def self.up
    create_table :deliverables_trackers, :id => false do |t|
      t.column :deliverable_id, :integer, :default => 0, :null => false
      t.column :tracker_id, :integer, :default => 0, :null => false
      t.column :created_on, :timestamp
      t.column :updated_on, :timestamp
    end
    
  end

  def self.down
    drop_table :deliverables_trackers
  end
end