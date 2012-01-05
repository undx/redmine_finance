class CreateBudgets < ActiveRecord::Migration
  def self.up
    create_table :budgets do |t|
      t.column :project_id, :integer, :default => 0, :null => false
      t.column :author_id, :integer, :default => 0, :null => false
      t.column :period, :date
      t.column :amount, :decimal, :precision => 15, :scale => 2
      t.column :created_on, :timestamp
      t.column :updated_on, :timestamp
    end
    
  end

  def self.down
    drop_table :budgets
  end
end
