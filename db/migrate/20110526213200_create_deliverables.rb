class CreateDeliverables < ActiveRecord::Migration
  def self.up
    create_table :deliverables do |t|
      t.column :id, :integer, :default => 0, :null => false
      t.column :name, :string, :default => "", :null => false
      t.column :description, :text, :null => true
      t.column :position, :integer
      t.column :amount, :decimal, :precision => 15, :scale => 2, :default => 0.0, :null => false
      t.column :ischangable, :boolean, :default => true
      t.column :validfrom, :date
      t.column :isactive, :boolean, :default => true
      t.column :created_on, :timestamp
      t.column :updated_on, :timestamp
    end
  end

  def self.down
    drop_table :deliverables
  end
end