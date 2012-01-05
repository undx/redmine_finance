module FinancesheetHelper
  
  def showing_users(users)
    l(:financesheet_showing_users) + users.collect(&:name).join(', ')
  end


  def link_to_csv_export(financesheet)
    link_to('CSV',
            {
              :controller => 'financesheet',
              :action => 'report',
              :format => 'csv',
              :financesheet => financesheet.to_param
            },
            :method => 'post',
            :class => 'icon icon-financesheet')
  end
  
  def link_to_pdf_export(financesheet)
    link_to('PDF',
            {
              :controller => 'financesheet',
              :action => 'report',
              :format => 'pdf',
              :financesheet => financesheet.to_param
            },
            :method => 'post',
            :class => 'icon icon-financesheet')
  end

  def link_swhitch_graph_table(financesheet)
      
     __view_type =  (financesheet.view_type.eql?("table")) ? "graph" : "table"
     __view_title = (financesheet.view_type.eql?("table")) ? "Gaphique" : "Table"
      
      link_to( __view_title,
            "#",
            :onclick => "$('financesheet_view_type').value = '#{__view_type}'; $('financesheet_report').submit();return false;",
            :class => 'icon icon-financesheet')
  end
  
  def toggle_issue_arrows(issue_id)
    js = "toggleDeliverableEntries('#{issue_id}'); return false;"
    
    return toggle_issue_arrow(issue_id, 'toggle-arrow-closed.gif', js, false) +
      toggle_issue_arrow(issue_id, 'toggle-arrow-open.gif', js, true)
  end
  
  def toggle_issue_arrow(issue_id, image, js, hide=false)
    style = "display:none;" if hide
    style ||= ''

    content_tag(:span,
                link_to_function(image_tag(image, :plugin => "redmine_finance"), js),
                :class => "toggle-" + issue_id.to_s,
                :style => style
                )
    
  end
  
  def link_to_deliverable(deliverable, options={})
    title = nil
    subject = nil
    title = truncate(deliverable.name, :length => 100)
    if options[:description] == true
      subject = deliverable.description
      if options[:truncate]
        subject = truncate(subject, :length => options[:truncate])
      end
    end
            
    s = "<div class='tooltip'>"
    s << link_to("##{deliverable.id} #{title}", {:controller => "deliverables", :action => "show", :id => deliverable}, 
                                                 :class => "tooltip",
                                                 :title => title)
    s << "<span class='tip'>#{h subject}</span>" if subject
    s << "</div>"
    s
  end
  
  # TODO replace deliverabl entries by deliverable amount
  def displayed_deliverable_entries_for_issue(deliverabl_entries)
    deliverabl_entries.collect(&:amount).sum
  end

  def project_options(financesheet)
    available_projects = financesheet.allowed_projects
    selected_projects = financesheet.projects.collect(&:id)
    selected_projects = available_projects.collect(&:id) if selected_projects.blank?
    
    options_from_collection_for_select(available_projects,
                                       :id,
                                       :name,
                                       selected_projects)
  end
  

  def user_options(financesheet)
    available_users = Financesheet.viewable_users.sort { |a,b| a.to_s.downcase <=> b.to_s.downcase }
    selected_users = financesheet.users

    options_from_collection_for_select(available_users,
                                       :id,
                                       :name,
                                       selected_users)

  end
  
  
  
end
