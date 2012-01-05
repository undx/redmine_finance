class Deliverable < ActiveRecord::Base
  include Redmine::SafeAttributes
  
  default_scope :order => "#{Deliverable.table_name}.position ASC"
  
  acts_as_list :column => :position

  
  
  has_and_belongs_to_many :trackers, :order => "#{Tracker.table_name}.position"
  has_many :deliverables, :class_name => "IssueDeliverables", :foreign_key => "deliverable_id"
  
  validates_presence_of :name, :description, :amount, :validfrom
  validates_numericality_of :amount, :allow_nil => false
  
  validates_associated :trackers
  
  def validate

    # Checks that the issue can not be added/moved to a disabled tracker
=begin    
    unless self.trackers.nil?
        errors.add :tracker_id, :empty
    end
=end
    
  end
  
  
end
