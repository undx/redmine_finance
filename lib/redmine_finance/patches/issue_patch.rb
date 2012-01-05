module RedmineFinance
  module Patches
    module IssuePatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable
          has_many :deliverables, :class_name => "IssueDeliverables", :foreign_key => "issue_id", :dependent => :delete_all
          
        def availableDeliverables                   
           @deliverables =  Deliverable.find(:all,
                                 :joins =>  "INNER JOIN #{DeliverablesTrackers.table_name} ON #{Deliverable.table_name}.id = #{DeliverablesTrackers.table_name}.deliverable_id",
                                 :conditions => " #{DeliverablesTrackers.table_name}.tracker_id = #{self.tracker.id} "+
                                                " AND  #{Deliverable.table_name}.isactive = 1 " +
                                                " AND  #{Deliverable.table_name}.validfrom <= current_date ",
                                 :order => "#{Deliverable.table_name}.name ASC, #{Deliverable.table_name}.amount ASC"
                              )
           return @deliverables
        end

        end
      end

      module ClassMethods
      end

      module InstanceMethods
      end
    end
  end
end