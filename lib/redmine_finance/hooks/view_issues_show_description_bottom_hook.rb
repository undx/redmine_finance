module RedmineFinance
  module Hooks
    class ViewIssuesFormDetailsBottomHook < Redmine::Hook::ViewListener
      render_on(:view_issues_show_description_bottom, :partial => 'issue_deliverables/index', :layout => false)
    end
    
    class RedmineMyPluginHookListener < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(context)
        stylesheet_link_tag '/plugin_assets/redmine_finance/stylesheets/financesheet.css'
      end
    end

  end
end