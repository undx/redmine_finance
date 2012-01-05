class AddInvocedOnToIssueDeliverables < ActiveRecord::Migration
   def self.up
    add_column :issue_deliverables, :invoiced_on, :date
  end
 
  def self.down
    remove_column :issue_deliverables, :invoiced_on
  end
end
