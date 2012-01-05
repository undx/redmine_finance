class BudgetsController < ApplicationController
  
  before_filter :find_project, :authorize, :only => :index
  before_filter :authorize_global
  before_filter :get_precision
  
  verify :method => :post, :only => [ :destroy],
         :redirect_to => { :action => :index }

  def index
    #@project = Project.find(params[:project_id])
    @budgets = Budget.find(:all,{:conditions => { :project_id => @project}, :order => "period"})
  end
    
  def new
    @budget = Budget.new(params[:budget])
    @project = Project.find(params[:id])
    @budget.project = @project
         
    if request.post? 
        @budget.period = Date.parse(params[:post][:"date(1i)"] +  params[:post][:"date(2i)"].rjust(2,'0') + params[:post][:"date(3i)"].rjust(2,'0'))
        @budget.author = User.current
        if @budget.save
          flash[:notice] = l(:notice_successful_create)
          redirect_to :action => 'index', :id => @project
        end
    end
  end
  
  def mass_new
    @project = Project.find(params[:id] != nil ? params[:id] : params[:project_id])
    @budget = Budget.new(params[:budget])
    @budget.project = @project
     
    @step = 'STEP_SHOW_DATE_RANGE'  
    
    if request.post? 
      if params[:step] == 'STEP_SHOW_MASS_FORM'
          
          
          @dtStart = Date.strptime(params[:rangeStart], '%Y-%m-%d')
          @dtEnd = Date.strptime(params[:rangeEnd], '%Y-%m-%d')
          
          @distributedAmount = 0
          @monthsList = months_between_dates(@dtStart, @dtEnd)
          
          if params[:isEqualDistribution] != nil && params[:isEqualDistribution] == 'distribute' && 
             params[:amount] != nil && params[:amount].to_i > 0
             
             @distributedAmount =  params[:amount].to_i /  @monthsList.length              
          end
          
          @step = 'STEP_SHOW_MASS_FORM'
          
      end # params[:step] == 'STEP_SHOW_MASS_FORM'
      
      if params[:step] == 'STEP_SAVE_MASS_FORM'
                
        notice = ""
        
        @budgets = params[:budgets] || {}
        @budgets.each do |budget| 
          
          __date = budget[:"date(1i)"].concat("-").concat(budget[:"date(2i)"].rjust(2,'0')).concat("-").concat(budget[:"date(3i)"].rjust(2,'0'))
          __budgets = Budget.find(:all,{:conditions => { 
                                        :project_id => @project, 
                                        :period => __date
                                        }})
          if !__budgets.empty? and __budgets.size() > 0
            @budget = __budgets.first
          else
             @budget = Budget.new  
          end
            
          @budget.project = @project
          
          @budget.amount = budget[:amount]
          @budget.period = Date.parse(__date)
          
          @budget.author = User.current
          
          if @budget.save
            notice.concat(l(@budget.period.strftime("%B")).concat(" ").concat(@budget.period.strftime("%Y")).concat(" ").concat(l(:notice_successful_create) + "<br/>"))
          end
          
        end
        
        flash[:notice] = notice
        redirect_to :action => 'index', :id => @project
        
      end
    end
  end
  
  def mass_update
    @project = Project.find(params[:id] != nil ? params[:id] : params[:project_id])
    @budget = Budget.new(params[:budget])
    @budget.project = @project
    if !request.post?
       @__budgets = Budget.find(:all,{:conditions => { :project_id => @project}})
    end
    if request.post?   
        notice = ""
        
        @budgets = params[:budgets] || {}
        @budgets.each do |budget| 
          
          __date = budget[:"date(1i)"].concat("-").concat(budget[:"date(2i)"].rjust(2,'0')).concat("-").concat(budget[:"date(3i)"].rjust(2,'0'))
          @budget = Budget.find(budget[:id])          
          @budget.amount = budget[:amount]
          @budget.period = Date.parse(__date)
                    
          if @budget.save
            notice.concat(l(@budget.period.strftime("%B")).concat(" ").concat(@budget.period.strftime("%Y")).concat(" ").concat(l(:notice_successful_update) + "<br/>"))
          end
        end
        flash[:notice] = notice
        redirect_to :action => 'index', :id => @project
      end
  end

  def edit
    @budget = Budget.find(params[:budget_edit])
    @project = Project.find(params[:id])
    if request.post? 
      # @budget.period = Date.parse(params[:post][:"date(1i)"] +  params[:post][:"date(2i)"].rjust(2,'0') + params[:post][:"date(3i)"].rjust(2,'0'))
      if @budget.update_attributes(params[:budget])
         
        flash[:notice] = l(:notice_successful_update)
        redirect_to :action => 'index', :id => @project
      end      
    end
  end
  
  def destroy
    @budget = Budget.find(params[:budget_destroy])
    @project = Project.find(params[:id])  
    @budget.destroy
    flash[:notice] = l(:notice_successful_destroy)
    redirect_to :action => 'index', :id => @project
  end
  
private
  def find_project
    @project = Project.find(params[:id])
    rescue ActiveRecord::RecordNotFound
    render_404
  end
  
   # build a months table
  def months_between_dates(dtBegin, dtEnd)
      
      # month tables
      monthsTab = Array.[]
      
      while dtBegin <= dtEnd
        monthsTab << dtBegin
        dtBegin >>= 1
      end
      
      # return the months dates array
      monthsTab
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
