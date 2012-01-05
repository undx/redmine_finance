class IssueDeliverablesController < ApplicationController
 
  before_filter :find_issue
  #before_filter :authorize, :only => [:new, :destroy]
  before_filter :get_precision
  
  accept_key_auth :index, :show, :create, :update, :destroy
  
  verify :method => :post, :only => [ :destroy],
         :redirect_to => { :action => :index }

  helper :journals
  
  def new
    
    if request.post? 
    
      @issuesDeliverables = params[:issue_deliverables] || {}
      total_amout = 0
      deliverables_notes ="|*"+l(:label_deliverable_name)+"*|*"+l(:label_issue_deliverables_comments)+"*|*"+l(:label_issue_deliverables_invoiced)+"*|*"+l(:label_issue_deliverables_amount)+"*|\n"
      flash[:notice] = ""
      
      updated = false
      
      @issuesDeliverables.each do |issueDeliverables|
        
         if !issueDeliverables[:deliverable_id].nil? && issueDeliverables[:deliverable_id].to_i > 0 && !issueDeliverables[:invoiced_on].nil?
           
           issueDeliverables.delete :v_amount
           
           @issueDeliverables = IssueDeliverables.new(issueDeliverables)
           @issue = Issue.find(issueDeliverables[:issue_id])
           @issueDeliverables.issue = @issue
           @issueDeliverables.project = @issue.project
           @deliverable = Deliverable.find(issueDeliverables[:deliverable_id])
           @issueDeliverables.deliverable = @deliverable
           @issueDeliverables.position = @deliverable.position
          
           @issueDeliverables.author = User.current
           
           total_amout = total_amout + @issueDeliverables.amount
           deliverables_notes = deliverables_notes + "|"+ @issueDeliverables.deliverable.name.gsub("|", "/") + "|" + @issueDeliverables.comments + "|" + (!@issueDeliverables.invoiced_on.nil? ? @issueDeliverables.invoiced_on.strftime("%d/%m/%Y") : " - ") + "|" + @issueDeliverables.amount.to_s + "|\n"
           
           if @issueDeliverables.save
              flash[:notice] = l(:notice_successful_create)
              updated = true
           end #end if
         else
           if(issueDeliverables[:invoiced_on].nil?)
               notice = l(:text_invoiced_date_must_be_setted)
           end
         end #end if                  
       end #end each

       if(updated)
         #Init notes to issue
         notes =""
         if(@issuesDeliverables.length >  1)
           notes = l(:notes_issue_deliverables_added, :total => total_amout)
         else 
          if(@issuesDeliverables.length == 1)
            notes = l(:notes_issue_deliverable_added, :total => total_amout)
          end
         end
         notes = notes + "\n" + deliverables_notes    
         @issue.init_journal(User.current, notes)
         if @issue.save
            flash[:notice] = flash[:notice] + "<BR/>" + l(:notice_issue_updated)
         end #end if
       end #end if updated
       
     end #end if
      redirect_to :controller => 'issues', :action => 'show', :id => @issue
  end
 

  def destroy
    @issueDeliverables = IssueDeliverables.find(params[:id])
    notes = l(:notes_issue_deliverable_deleted) + "\n" + " * " +  @issueDeliverables.deliverable.name
    
    if request.post?
      @issueDeliverables.destroy
      
       
      @issue.init_journal(User.current, notes)
      @issue.save
               
      @issue.reload
      @journals = @issue.journals.find(:all, :include => [:user, :details], :order => "#{Journal.table_name}.created_on ASC")
      @journals.each_with_index {|j,i| j.indice = i+1}
      @journals.reverse! if User.current.wants_comments_in_reverse_order?
      
    end
    
    respond_to do |format|
      format.html { redirect_to :controller => 'issues', :action => 'show', :id => @issue }
      format.js {
        render(:update) {
          |page|
             page.replace_html "issue_deliverables", :partial => 'issue_deliverables/index_detail2'
             page.replace_html "history", :partial => 'issues/history', :locals => { :issue => @issue, :journals => @journals }
             
        }
      }
     end
     
  end
  
  def update
    
  end
  
 private
  def find_issue
    @issue = @object = Issue.find(params[:issue_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def get_precision
    precision = Setting.plugin_redmine_finance['precision']
    
    if precision.blank?
      # Set precision to a high number
      @precision = 10
    else
      @precision = precision.to_i
    end
  end
end