if RAILS_ENV == "development" 
  ActiveSupport::Dependencies.load_once_paths.reject!{|x| x =~ /^#{Regexp.escape(File.dirname(__FILE__))}/}
end

require 'redmine'

# Taken from lib/redmine.rb
if RUBY_VERSION < '1.9'
  require 'faster_csv'
else
  require 'csv'
  FCSV = CSV
end

unless Redmine::Plugin.registered_plugins.keys.include?(:redmine_finance)
  Redmine::Plugin.register :redmine_finance do
    name 'Redmine Finance plugin'
    author 'Altic'
    description 'This is a plugin for Redmine'
    version '0.0.2'
    url 'http://altic.org/redmine/plugin/finances'
    author_url 'http://altic.org'
    
    requires_redmine :version_or_higher => '1.0.0'
    
    # These settings are set automatically when caching
    settings(:default => {
                 'last_caching_run' => nil,
                 'list_size' => '5',
                 'precision' => '2',
                 'project_status' => 'active',
                 'user_status' => 'active'
               })
     # TODO Check all permission
     project_module :finances do
        #permission :manage_deliverable, { :deliverables => [:index, :new, :create, :edit, :update, :destroy, :trackers]}
        permission :view_deliverable, { :deliverables => [:show]}
        permission :manage_budget, { :budgets => [:index, :new, :create, :edit, :update, :destroy, :show, :mass_new, :mass_update]}
        permission :view_budget, { :budgets => [:index]}
        permission :manage_issue_deliverables, { :issue_deliverables => [:new, :destroy]}
        permission :update_issue_deliverables, { :issue_deliverables => [:update]}
        permission :view_issue_deliverables, { :issue_deliverables => [:index]}
        permission :report_finance, { :financesheet => [:index, :report, :restet, :context_menu], :financesheet_graphs => [:budget_vs_actual_graph]}
     end
     
     permission :member_finances, { 
          :deliverables => [:index, :new, :create, :show, :edit, :update, :destroy, :trackers],
          :issue_deliverables => [:index, :new, :create, :show, :edit, :update, :destroy],
          :budgets => [:index, :new, :create, :edit, :update, :destroy],
          :financesheet => [:index, :report]      
          }, 
          :require => :member
          
     permission :admin_finances, { 
          :deliverables => [:index, :new, :create, :edit, :update, :destroy, :trackers]
          }, 
          :require => :admin
  
     menu( :admin_menu, 
           :deliverables, { :controller => 'deliverables', :action => 'index' }, 
           :caption => :label_deliverable_plural, 
           
           :if => Proc.new {
             User.current.admin?
           })

     menu( :project_menu, 
           :budgets, { :controller => 'budgets', :action => 'index'}, 
           :caption => :label_budget_plural, 
           :id => @project,
           :if => Proc.new {
             User.current.allowed_to?(:manage_budget, nil, :global => true)||
             User.current.allowed_to?(:view_budget, nil, :global => true) ||
             User.current.admin?
           })
           
     menu(:top_menu, :financesheet,{:controller => 'financesheet', :action => 'index'}, :after => :projects, :caption => :financesheet_title,
           :if => Proc.new {
             User.current.allowed_to?(:report_finance, nil, :global => true) ||
             User.current.admin?
           })
           
     #overwrite menu project
     delete_menu_item(:project_menu, :new_issue)
     menu( :project_menu,
           :new_issue, { :controller => 'issues', :action => 'new'},
           :caption => :label_issue_new,
           :param => :project_id, 
           :project_id => @project,           
           #:html => {
           #  :style => 'float: right; margin-left: 30px; border-left: 1px solid rgb(255, 255, 255);'
           #},
           :before => :issues
           )
  end
end

require 'dispatcher'
Dispatcher.to_prepare :redmine_finance do
  
  require_dependency 'issue'
  Issue.send(:include, RedmineFinance::Patches::IssuePatch)
  
  require_dependency 'principal'
  require_dependency 'user'
  User.send(:include, RedmineFinance::Patches::UserPatch)

  require_dependency 'project'
  Project.send(:include, RedmineFinance::Patches::ProjectPatch)
  
end

require 'redmine_finance/hooks/view_issues_show_description_bottom_hook'
