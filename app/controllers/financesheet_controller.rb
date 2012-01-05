class FinancesheetController < ApplicationController
  unloadable

  layout 'base'
  before_filter :get_list_size
  before_filter :get_precision

  helper :sort
  include SortHelper
  helper :issues
  include ApplicationHelper
  helper :timelog

  SessionKey = 'financesheet_filter'

  verify :method => :delete, :only => :reset, :render => {:nothing => true, :status => :method_not_allowed }

  def index
    load_filters_from_session
    unless @financesheet
      @financesheet ||= Financesheet.new
    end
    @financesheet.allowed_projects = allowed_projects

    if @financesheet.allowed_projects.empty?
      render :action => 'no_projects'
      return
    end
  end

  def report

    if params && params[:financesheet]
      @financesheet = Financesheet.new( params[:financesheet] )
    else
      redirect_to :action => 'index'
      return
    end
    
    @financesheet.allowed_projects = allowed_projects
    
    
    
    if @financesheet.allowed_projects.empty?
      render :action => 'no_projects'
      return
    end

    if !params[:financesheet][:projects].blank?
      @financesheet.projects = @financesheet.allowed_projects.find_all { |project|
        params[:financesheet][:projects].include?(project.id.to_s)
      }
    else
      @financesheet.projects = @financesheet.allowed_projects
    end
    
    if !params[:financesheet][:view_type].blank?
       @financesheet.view_type = params[:financesheet][:view_type]
    end
    
    

    call_hook(:financesheet_controller_report_pre_fetch_deliverable_entries, { :financesheet => @financesheet, :params => params })
    
    
    

    save_filters_to_session(@financesheet)

    @financesheet.fetch_deliverable_entries

    # Sums
    @total = { }
    @total_by_period = { }
    @gand_total_by_period = { }
    
    @min_date_entries = { }
    @max_date_entries = { }
    
    @data_budgets = Array.new
    @data_deliverables = Array.new
    
    unless @financesheet.sort == :issue
      
      @financesheet.deliverable_entries.each do |project,logs|
        
        @total[project] = 0
        @min_date_entries[project] = Date.today >> (30 * 12)
        @max_date_entries[project] = Date.today << (30 * 12)
    
        if logs[:logs]
          logs[:logs].each do |log|
            
            @min_date_entries[project] = (@min_date_entries[project] <=> log.invoiced_on) == -1 ? @min_date_entries[project] : log.invoiced_on
            @max_date_entries[project] = (@max_date_entries[project] <=> log.invoiced_on) == 1 ? @max_date_entries[project] : log.invoiced_on
            
            @total[project] += log.amount
            
            if !log.invoiced_on.nil? && @financesheet.sort == :user
              
                  case @financesheet.view_by
                  when :Year then
                    if(@total_by_period[log.author_id.to_s + "_" + log.invoiced_on.year.to_s].nil?)
                      @total_by_period[log.author_id.to_s + "_" + log.invoiced_on.year.to_s] = 0
                    end
                    @total_by_period[log.author_id.to_s + "_" + log.invoiced_on.year.to_s] += log.amount
                    
                    if(@gand_total_by_period[log.invoiced_on.year.to_s].nil?)
                      @gand_total_by_period[log.invoiced_on.year.to_s] = 0
                    end
                    @gand_total_by_period[log.invoiced_on.year.to_s] += log.amount
                                        
                  when :Month then
                    if(@total_by_period[log.author_id.to_s + "_" + log.invoiced_on.strftime("%Y%m").to_s].nil?)
                      @total_by_period[log.author_id.to_s + "_" + log.invoiced_on.strftime("%Y%m").to_s] = 0
                    end
                     @total_by_period[log.author_id.to_s + "_" + log.invoiced_on.strftime("%Y%m").to_s] += log.amount
                     
                    if(@gand_total_by_period[log.invoiced_on.strftime("%Y%m").to_s].nil?)
                      @gand_total_by_period[log.invoiced_on.strftime("%Y%m").to_s] = 0
                    end
                    @gand_total_by_period[log.invoiced_on.strftime("%Y%m").to_s] += log.amount   
                    
                  when :Week then
                    if(@total_by_period[log.author_id.to_s + "_" + log.invoiced_on.strftime("%Y%W")].nil?)
                      @total_by_period[log.author_id.to_s + "_" + log.invoiced_on.strftime("%Y%W")] = 0
                    end
                     @total_by_period[log.author_id.to_s + "_" + log.invoiced_on.strftime("%Y%W")] += log.amount
                     
                    if(@gand_total_by_period[log.invoiced_on.strftime("%Y%W")].nil?)
                      @gand_total_by_period[log.invoiced_on.strftime("%Y%W")] = 0
                    end
                    @gand_total_by_period[log.invoiced_on.strftime("%Y%W")] += log.amount 
                  end
              end
              if !log.invoiced_on.nil? && @financesheet.sort == :project
        
                case @financesheet.view_by
                when :Year then
                  if(@total_by_period[project + "_" + log.invoiced_on.year.to_s].nil?)
                    @total_by_period[project + "_" + log.invoiced_on.year.to_s] = 0
                  end
                  @total_by_period[project + "_" + log.invoiced_on.year.to_s] += log.amount
                  
                  if(@gand_total_by_period[log.invoiced_on.year.to_s].nil?)
                     @gand_total_by_period[log.invoiced_on.year.to_s] = 0
                  end
                  @gand_total_by_period[log.invoiced_on.year.to_s] += log.amount
                    
                when :Month then
                  if(@total_by_period[project + "_" + log.invoiced_on.strftime("%Y%m").to_s].nil?)
                    @total_by_period[project + "_" + log.invoiced_on.strftime("%Y%m").to_s] = 0
                  end
                   @total_by_period[project + "_" + log.invoiced_on.strftime("%Y%m").to_s] += log.amount
                   
                  if(@gand_total_by_period[log.invoiced_on.strftime("%Y%m").to_s].nil?)
                    @gand_total_by_period[log.invoiced_on.strftime("%Y%m").to_s] = 0
                  end
                  @gand_total_by_period[log.invoiced_on.strftime("%Y%m").to_s] += log.amount 
                     
                when :Week then
                  if(@total_by_period[project + "_" + log.invoiced_on.strftime("%Y%W")].nil?)
                    @total_by_period[project + "_" + log.invoiced_on.strftime("%Y%W")] = 0
                  end
                   @total_by_period[project + "_" + log.invoiced_on.strftime("%Y%W")] += log.amount
                   
                  if(@gand_total_by_period[log.invoiced_on.strftime("%Y%W")].nil?)
                    @gand_total_by_period[log.invoiced_on.strftime("%Y%W")] = 0
                  end
                  @gand_total_by_period[log.invoiced_on.strftime("%Y%W")] += log.amount 
                end
            end
            
          end
        end
      end
    else
      @financesheet.deliverable_entries.each do |project, project_data|
        
        @total[project] = 0

        @min_date_entries[project.name] = Date.today >> (30 * 12)
        @max_date_entries[project.name] = Date.today << (30 * 12)
       
        if project_data[:issues]
          project_data[:issues].each do |issue, _issue_deliverables|
                    
            _issue_deliverables.each do |_issue_deliverable|
            
              @total[project] += _issue_deliverable.amount
            
            @min_date_entries[project.name] = (@min_date_entries[project.name] <=> _issue_deliverable.invoiced_on) == -1 ? @min_date_entries[project.name] : _issue_deliverable.invoiced_on
            @max_date_entries[project.name] = (@max_date_entries[project.name] <=> _issue_deliverable.invoiced_on) == 1 ? @max_date_entries[project.name] : _issue_deliverable.invoiced_on
              
               case @financesheet.view_by
                  when :Year then
                    if(@total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.year.to_s].nil?)
                      @total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.year.to_s] = 0
                    end
                    @total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.year.to_s] += _issue_deliverable.amount
                    
                    if(@gand_total_by_period[_issue_deliverable.invoiced_on.year.to_s].nil?)
                       @gand_total_by_period[_issue_deliverable.invoiced_on.year.to_s] = 0
                    end
                    @gand_total_by_period[_issue_deliverable.invoiced_on.year.to_s] += _issue_deliverable.amount
                    
                  when :Month then
                    if(@total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.strftime("%Y%m").to_s].nil?)
                      @total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.strftime("%Y%m").to_s] = 0
                    end
                     @total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.strftime("%Y%m").to_s] += _issue_deliverable.amount
                     
                    if(@gand_total_by_period[_issue_deliverable.invoiced_on.strftime("%Y%m").to_s].nil?)
                      @gand_total_by_period[_issue_deliverable.invoiced_on.strftime("%Y%m").to_s] = 0
                    end
                    @gand_total_by_period[_issue_deliverable.invoiced_on.strftime("%Y%m").to_s] += _issue_deliverable.amount 
                    
                  when :Week then
                    if(@total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.strftime("%Y%W")].nil?)
                      @total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.strftime("%Y%W")] = 0
                    end
                     @total_by_period[project.name + "_" + _issue_deliverable.invoiced_on.strftime("%Y%W")] += _issue_deliverable.amount
                     
                    if(@gand_total_by_period[_issue_deliverable.invoiced_on.strftime("%Y%W")].nil?)
                      @gand_total_by_period[_issue_deliverable.invoiced_on.strftime("%Y%W")] = 0
                    end
                    @gand_total_by_period[_issue_deliverable.invoiced_on.strftime("%Y%W")] += _issue_deliverable.amount 
                end  
               end 
            
          end
        end
      end
    end
    

    @grand_total = @total.collect{|k,v| v}.inject{|sum,n| sum + n}
    
    
     if( @financesheet.view_type.eql?("graph"))
       
       @gand_total_by_period.each_pair do |t_k,t_v|
         case @financesheet.view_by
         when :Year then
            @data_deliverables.push(Date.civil(t_k.to_i, 1, 1))
         when :Month then
            @data_deliverables.push(Date.civil(t_k[0,4].to_i, t_k[4 , t_k.length - 1].to_i, 1))
         when :Week then
            @data_deliverables.push(Date.commercial(t_k[0,4].to_i, t_k[4 , t_k.length - 1].to_i , 1))
         end         
         @data_deliverables.push(t_v)
      end
     end

    @financesheet.fetch_budgets() 

    @min_budget_entries = []
    @max_budget_entries = []
           
    @financesheet.budgets_entries.each_pair do |budget_k,budget_v|
      
      prj = budget_k.split("~")[0]
      budget_k = budget_k.split("~")[1]      
      
      case @financesheet.view_by
      when :Year then        
        
        if !@min_date_entries[prj].nil? && budget_k.to_i < @min_date_entries[prj].year
          @min_budget_entries << { "_project" => prj.to_s, "date" => budget_k, "budget" => budget_v, "_sort" => budget_k, "_date" => Date.civil(budget_k.to_i, 1 , 1)}
        end
        if !@max_date_entries[prj].nil?  &&  budget_k.to_i > @max_date_entries[prj].year
          @max_budget_entries <<  { "_project" => prj.to_s, "date" => budget_k, "budget" => budget_v, "_sort" => budget_k, "_date" => Date.civil(budget_k.to_i, 1 , 1)}
        end
        if( @financesheet.view_type.eql?("graph"))
          @data_budgets.push(Date.civil(budget_k.to_i,1, 1))
          @data_budgets.push(budget_v)
        end
      when :Month then
        if !@min_date_entries[prj].nil? && (budget_k.to_i < (@min_date_entries[prj].strftime("%Y%m")).to_i)
          _d = Date.civil(budget_k.to_s[0,4].to_i, budget_k.to_s[4 , budget_k.to_s.length - 1].to_i, 1)
          @min_budget_entries << { "_project" => prj.to_s, "date" => l(_d.strftime("%B")) + " " + _d.strftime("%Y"), "budget" => budget_v , "_sort" => budget_k, "_date" => Date.civil(budget_k[0,4].to_i, budget_k[4 , budget_k.length - 1].to_i , 1) }
        end
        if !@max_date_entries[prj].nil?  &&  (budget_k.to_i > (@max_date_entries[prj].strftime("%Y%m")).to_i)
          _d = Date.civil(budget_k.to_s[0,4].to_i, budget_k.to_s[4 , budget_k.to_s.length - 1].to_i, 1)
          @max_budget_entries <<  { "_project" => prj.to_s, "date" => l(_d.strftime("%B")) + " " + _d.strftime("%Y"), "budget" => budget_v, "_sort" => budget_k, "_date" =>  Date.civil(budget_k[0,4].to_i, budget_k[4 , budget_k.length - 1].to_i , 1)}
        end
        if( @financesheet.view_type.eql?("graph"))
          @data_budgets.push(Date.civil(budget_k.to_s[0,4].to_i, budget_k.to_s[4 , budget_k.to_s.length - 1].to_i, 1))
          @data_budgets.push(budget_v)
        end
      when :Week then
        if !@min_date_entries[prj].nil?  && budget_k.to_i < (@min_date_entries[prj].strftime("%Y%W")).to_i
          @min_budget_entries <<  { "_project" => prj.to_s, "date" => l(:financesheet_week) + " " + budget_k.to_s[4 , budget_k.to_s.length - 1] + " " + budget_k.to_s[0,4], "budget" => budget_v, "_sort" => budget_k, "_date" => Date.commercial(budget_k[0,4].to_i, budget_k[4 , budget_k.length - 1].to_i , 1)}
        end
        if !@max_date_entries[prj].nil?  &&  budget_k.to_i > (@max_date_entries[prj].strftime("%Y%W")).to_i          
          @max_budget_entries << { "_project" => prj.to_s, "date" => l(:financesheet_week) + " " + budget_k[4 , budget_k.length - 1] + " " + budget_k[0,4], "budget" => budget_v, "_sort" => budget_k, "_date" => Date.commercial(budget_k[0,4].to_i, budget_k[4 , budget_k.length - 1].to_i > 0 ? budget_k[4 , budget_k.length - 1].to_i : 1  , 1)}
        end
        if( @financesheet.view_type.eql?("graph"))
          @data_budgets.push(Date.commercial(budget_k[0,4].to_i, budget_k[4 , budget_k.length - 1].to_i > 0 ? budget_k[4 , budget_k.length - 1].to_i : 1, 1))
          @data_budgets.push(budget_v)
        end
      end
      
    end
    

    @lineOk = { }
    
    @min_budget_entries = @min_budget_entries.sort_by { |item|item["_sort"].to_i } 
    @max_budget_entries = @max_budget_entries.sort_by { |item|item["_sort"].to_i } 
    
    respond_to do |format|
      format.html { render :action => 'details', :layout => false if request.xhr? }
      format.csv  { send_data @financesheet.to_csv, :filename => 'financesheet.csv', :type => "text/csv" }
      format.pdf  { send_data @financesheet.to_pdf, :filename => 'financesheet.pdf', :type => "application/pdf" }
    end
  end
  
  def context_menu
    @deliverable_entries = IssueDeliverables.find(:all, :conditions => ['id IN (?)', params[:ids]])
    render :layout => false
  end

  def reset
    clear_filters_from_session
    redirect_to :action => 'index'
  end

  private
  def get_list_size
    @list_size = Setting.plugin_redmine_finance['list_size'].to_i
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

  def allowed_projects
    if User.current.admin?
      Project.finance_order_by_name
    elsif Setting.plugin_redmine_finance['project_status'] == 'all'
      Project.finance_order_by_name.finance_with_membership(User.current)
    else
      Project.finance_order_by_name.all(:conditions => Project.visible_by(User.current))
    end
  end

  def clear_filters_from_session
    session[SessionKey] = nil
  end

  def load_filters_from_session
    if session[SessionKey]
      @financesheet = Financesheet.new(session[SessionKey])
      # Default to free period
      @financesheet.period_type = Financesheet::ValidPeriodType[:free_period]
    end

    if session[SessionKey] && session[SessionKey]['projects']
      @financesheet.projects = allowed_projects.find_all { |project|
        session[SessionKey]['projects'].include?(project.id.to_s)
      }
    end
  end

  def save_filters_to_session(financesheet)
    if params[:financesheet]
      # Check that the params will fit in the session before saving
      # prevents an ActionController::Session::CookieStore::CookieOverflow
      encoded = Base64.encode64(Marshal.dump(params[:financesheet]))
      if encoded.size < 2.kilobytes # Only use 2K of the cookie
        session[SessionKey] = params[:financesheet]
      end
    end

    if financesheet
      session[SessionKey] ||= {}
      session[SessionKey]['date_from'] = financesheet.date_from
      session[SessionKey]['date_to'] = financesheet.date_to
    end
  end
end
