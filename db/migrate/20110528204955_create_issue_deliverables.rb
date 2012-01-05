class CreateIssueDeliverables < ActiveRecord::Migration
  def self.up
    create_table :issue_deliverables do |t|
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :issue_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false      
      t.column :deliverable_id, :integer, :default => 0, :null => false
      t.column :position, :integer
      t.column :amount, :decimal, :precision => 15, :scale => 2, :default => 0, :null => false
      t.column :ischangable, :boolean
      t.column :comments, :string, :null => true
      t.column :created_on, :timestamp
      t.column :updated_on, :timestamp
    end
  end

  def self.down
    drop_table :issue_deliverables
  end
end
