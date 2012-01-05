class DeliverablesTrackers < ActiveRecord::Base
  include Redmine::SafeAttributes
  
  has_and_belongs_to_many :deliverables, :order => "#{Deliverable.table_name}.name"
  has_and_belongs_to_many :trakers, :order => "#{Tracker.table_name}.name"
  
end