class IssueDeliverables < ActiveRecord::Base
  
  unloadable
  
  default_scope :order => "#{IssueDeliverables.table_name}.position ASC"
  
  belongs_to :project
  belongs_to :issue
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  belongs_to :deliverable
  
  
  attr_protected :project_id, :issue_id, :deliverable_id
  
  validates_presence_of :project_id, :issue_id, :deliverable_id, :amount, :invoiced_on
  validates_numericality_of :amount, :allow_nil => false
  validates_length_of :comments, :maximum => 255, :allow_nil => true

end
