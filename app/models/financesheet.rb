class Financesheet
  

  require 'SVG/Graph/TimeSeries'
  require 'rfpdf'
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::NumberHelper
    
  def logger
        RAILS_DEFAULT_LOGGER
  end

  attr_accessor :date_from, :date_to, :projects, :users, :allowed_projects, :period, :period_type

  # deliverables entries on the Financesheet in the form of:
  # project.name => {:logs => [deliverable entries], :users => [users shown in logs] }
  # project.name => {:logs => [deliverable entries], :users => [users shown in logs] }
  # project.name could be the parent project name also
  attr_accessor :deliverable_entries
  
  # Array of DeliverableEntry ids to fetch
  attr_accessor :potential_deliverable_entry_ids

  # Sort deliverable entries by this field
  attr_accessor :sort
  
  # manage budgets
  attr_accessor :view_by
  attr_accessor :view_type
  attr_accessor :budgets_entries
  
  ValidSortOptions = {
    :project => I18n.t(:project),
    :user => I18n.t(:user),
    :issue => I18n.t(:issue)
  }
  
  ValidViewOptions = {
    :Year => I18n.t(:Year),
    :Month => I18n.t(:Month),
    :Week => I18n.t(:Week)
  }

  ValidPeriodType = {
    :free_period => 0,
    :default => 1
  }
  
  def initialize(options = { })
    
    self.projects = [ ]
    self.deliverable_entries = options[:deliverable_entries] || { }
    self.potential_deliverable_entry_ids = options[:potential_deliverable_entry_ids] || [ ]
    self.allowed_projects = options[:allowed_projects] || [ ]

    unless options[:users].nil?
      self.users = options[:users].collect { |u| u.to_i }
    else
      self.users = Financesheet.viewable_users.collect {|user| user.id.to_i }
    end

    if !options[:sort].nil? && options[:sort].respond_to?(:to_sym) && ValidSortOptions.keys.include?(options[:sort].to_sym)
      self.sort = options[:sort].to_sym
    else
      self.sort = :project
    end
    
    self.date_from = options[:date_from] || Date.today.to_s
    self.date_to = options[:date_to] || Date.today.to_s

    if options[:period_type] && ValidPeriodType.values.include?(options[:period_type].to_i)
      self.period_type = options[:period_type].to_i
    else
      self.period_type = ValidPeriodType[:free_period]
    end
    self.period = options[:period] || nil
    
    if !options[:view_by].nil? && options[:view_by].respond_to?(:to_sym) && ValidViewOptions.keys.include?(options[:view_by].to_sym)
      self.view_by = options[:view_by].to_sym
    else
      self.view_by = :year
    end
    
    if !options[:view_type].nil? && options[:view_type].respond_to?(:to_sym) && ValidViewOptions.keys.include?(options[:view_type].to_sym)
      self.view_type = options[:view_type].to_sym
    else
      self.view_type = :table
    end
    
    
    
  end

  # Gets all the deliverable_entries for all the projects
  def fetch_deliverable_entries
    self.deliverable_entries = { }
    case self.sort
    when :project
      fetch_deliverable_entries_by_project
    when :user
      fetch_deliverable_entries_by_user
    when :issue
      fetch_deliverable_entries_by_issue
    else
      fetch_deliverable_entries_by_project
    end
  end
  
  # Gets all the budgets for all the projects
  def fetch_budgets
    self.budgets_entries = { }
    case self.view_by
    when :Year
      self.budgets_entries = fetch_budgets_entries_by_year
    when :Month
      self.budgets_entries = fetch_budgets_entries_by_month
    when :Week
      self.budgets_entries = fetch_budgets_entries_by_week
    else
      self.budgets_entries = fetch_budgets_entries_by_year
    end
  end

  def period=(period)
    return if self.period_type == Financesheet::ValidPeriodType[:free_period]
    # Stolen from the TimelogController
    case period.to_s
    when 'today'
      self.date_from = self.date_to = Date.today
    when 'yesterday'
      self.date_from = self.date_to = Date.today - 1
    when 'current_week' # Mon -> Sun
      self.date_from = Date.today - (Date.today.cwday - 1)%7
      self.date_to = self.date_from + 6
    when 'last_week'
      self.date_from = Date.today - 7 - (Date.today.cwday - 1)%7
      self.date_to = self.date_from + 6
    when '7_days'
      self.date_from = Date.today - 7
      self.date_to = Date.today
    when 'current_month'
      self.date_from = Date.civil(Date.today.year, Date.today.month, 1)
      self.date_to = (self.date_from >> 1) - 1
    when 'last_month'
      self.date_from = Date.civil(Date.today.year, Date.today.month, 1) << 1
      self.date_to = (self.date_from >> 1) - 1
    when '30_days'
      self.date_from = Date.today - 30
      self.date_to = Date.today
    when 'current_year'
      self.date_from = Date.civil(Date.today.year, 1, 1)
      self.date_to = Date.civil(Date.today.year, 12, 31)
    when 'all'
      self.date_from = self.date_to = nil
    end
    self
  end

  def to_param (_view_type=nil)
    {
      :projects => projects.collect(&:id),
      :date_from => date_from,
      :date_to => date_to,
      :users => users,
      :sort => sort,
      :view_by => view_by,
      :view_type => _view_type.nil? ? view_type : _view_type
    }
  end

  def to_csv
    returning '' do |out|
      FCSV.generate out do |csv|
        csv << csv_header

        # Write the CSV based on the group/sort
        case sort
        when :user, :project
          deliverable_entries.sort.each do |entryname, entry|
            entry[:logs].each do |e|
              csv << deliverable_entry_to_csv(e)
            end
          end
        when :issue
          deliverable_entries.sort.each do |project, entries|
            entries[:issues].sort {|a,b| a[0].id <=> b[0].id}.each do |issue, deliverable_entries|
              deliverable_entries.each do |e|
                csv << deliverable_entry_to_csv(e)
              end
            end
          end
        end
      end
    end
  end
  
  
  def to_pdf
    myFont = 'Helvetica'
    #titles table
    t = ['#','date',l(:label_member),l(:label_project),l(:label_issue),"#{l(:label_issue)} #{l(:field_subject)}",l(:label_issue_status),l(:field_description),l(:label_deliverable_name),l(:label_deliverable_amount)]
    #colum_size table
    cs = [10,20,20,20,20,30,20,87,30,20] 
    #colum_size table associative
    csa = {"num"=>10,"date"=>20,"member"=>20,"project"=>20,"issue"=>20,"subject"=>30,"status"=>20,"description"=>87,"deliverable_name"=>30,"deliverable_amount"=>20} 
    #colum header height
    ch = 6
    #data height
    dh = 6
    #conv=Iconv.new('iso-8859-15', 'utf-8')
    #conv=Iconv.new('utf-8', 'iso-8859-15')
    conv=Iconv.new(l(:general_pdf_encoding), 'UTF-8')
#Préparation du PDF  
    mypdf = FPDF.new('L','mm','A4')
    mypdf.SetAutoPageBreak(false)
    #création de la première page
    mypdf= initpage(mypdf)
       
#Récupération des informations à afficher
    precision = Setting.plugin_redmine_finance['precision']
    data = Array.new
    # Write the pdf based on the group/sort
      case sort
      when :user, :project
        deliverable_entries.sort.each do |entryname, entry|
          entry[:logs].each do |e|
            data << deliverable_entry_to_pdf(e, precision)
          end
        end
      when :issue
        deliverable_entries.sort.each do |project, entries|
          entries[:issues].sort {|a,b| a[0].id <=> b[0].id}.each do |issue, deliverable_entries|
            deliverable_entries.each do |e|
              data << deliverable_entry_to_pdf(e, precision)
            end
          end
        end
      end    

#Remplissage du PDF avec le contenu 
    #sauvegarde des positions de départ
    x0 = mypdf.GetX()
    x1 = x0
    y1 = mypdf.GetY()
    
    font_size=8
    mypdf.SetFont(myFont,'',font_size);
    mypdf.SetFillColor(0)
    ##pour chaque ligne à afficher
    data.each do |d|
      x1=x0
      #détermination du nombre de ligne maximum dans l'entete
      nb_line_size=1
      i=0
      d.each do |key,value|
        if key!="deliverable_comment"
          s=(mypdf.GetStringWidth(d[key])/csa[key]).round+1
          if (s>nb_line_size)
            nb_line_size=s
          end
          i=i+1
        end
      end
      #check si on doit aller à la page suivante, => ecriture du footer et ajout de page
       if mypdf.GetY+nb_line_size*font_size>200
        #ecriture du footer
        mypdf=addfooter(mypdf)
        #ajout page
        mypdf=initpage(mypdf)
        x0 = mypdf.GetX()
        x1 = x0
        y1 = mypdf.GetY()
        font_size=8
        mypdf.SetFont(myFont,'',font_size);
        mypdf.SetFillColor(0)
      end
      #écriture des lignes
      i=0
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,d["num"],0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,d["date"],0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,conv.iconv(d["member"]),0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,conv.iconv(d["project"]),0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,conv.iconv(d["issue"]),0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,conv.iconv(d["subject"]),0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,conv.iconv(d["status"]),0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,conv.iconv(d["description"]),0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,conv.iconv(d["deliverable_name"]),0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'D')
      mypdf.MultiCell(cs[i],ch,d["deliverable_amount"],0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
      
      y1=y1+nb_line_size*font_size
      mypdf.SetXY(x0,y1) 
     
    end
    mypdf = addfooter(mypdf)
    mypdf.Output();
=begin
// affiche le document test.PDF dans une iframe.
echo '
  <iframe src="test.PDF" width="100%" height="100%">
  [Your browser does <em>not</em> support <code>iframe</code>,
  or has been configured not to display inline frames.
  You can access <a href="./test.PDF">the document</a>
  via a link though.]</iframe>
's;
=end
  end

  def self.viewable_users
    if Setting['plugin_redmine_finance'].present? && Setting['plugin_redmine_finance']['user_status'] == 'all'
      user_scope = User.all
    else
      user_scope = User.active
    end
    user_scope.select {|user|
      user.allowed_to?(:manage_issue_deliverables, nil, :global => true)
    }
  end
  
  
####################### PROTECTED ###########################################
  protected

  def csv_header
    csv_data = [
                '#',
                l(:label_date),
                l(:label_member),
                l(:label_project),
                l(:label_issue),
                "#{l(:label_issue)} #{l(:field_subject)}",
                l(:label_issue_status),
                l(:field_description),
                l(:label_issue_deliverables_name),
                l(:label_issue_deliverables_description),
                l(:label_issue_deliverables_comments),
                l(:label_issue_deliverables_amount)
               ]
    Redmine::Hook.call_hook(:plugin_redmine_finance_model_financesheet_csv_header, { :financesheet => self, :csv_data => csv_data})
    return csv_data
  end

  def deliverable_entry_to_csv(deliverable_entry)
    csv_data = [
                deliverable_entry.id,
                deliverable_entry.invoiced_on,
                deliverable_entry.author.name,
                deliverable_entry.project.name,
                ("#{deliverable_entry.issue.tracker.name} ##{deliverable_entry.issue.id}" if deliverable_entry.issue),
                (deliverable_entry.issue.subject if deliverable_entry.issue),
                deliverable_entry.issue.status,
                (deliverable_entry.issue.description[0..100] if deliverable_entry.issue.description),
                deliverable_entry.deliverable.name,
                deliverable_entry.deliverable.description,
                deliverable_entry.comments,
                deliverable_entry.amount
               ]
    Redmine::Hook.call_hook(:plugin_redmine_finance_model_financesheet_deliverable_entry_to_csv, { :financesheet => self, :deliverable_entry => deliverable_entry, :csv_data => csv_data})
    return csv_data
  end
  
  def deliverable_entry_to_pdf(deliverable_entry, precision) 
   
   conv_to_iso_win = Iconv.new('windows-1252', 'utf-8')

   pdf_data = {
                "num" =>  deliverable_entry.id.to_s,
                "date" => deliverable_entry.invoiced_on.strftime('%d/%m/%Y'), #TODO quelle date ??
                "member" => deliverable_entry.author.name,
                "project" => deliverable_entry.project.name,
                "issue" => ("#{deliverable_entry.issue.tracker.name} ##{deliverable_entry.issue.id}" if deliverable_entry.issue),
                "subject" => ("#{deliverable_entry.issue.subject}" if deliverable_entry.issue),
                "status" => ("#{deliverable_entry.issue.status}"if deliverable_entry.issue),
                "description" => (deliverable_entry.issue.description[0..100] if deliverable_entry.issue.description),
                "deliverable_name" => (deliverable_entry.deliverable.name if deliverable_entry.deliverable.name),
                "deliverable_comment" => !deliverable_entry.comments.nil? ? deliverable_entry.comments : "",
                "deliverable_amount" => conv_to_iso_win.iconv(number_to_currency(deliverable_entry.amount, :precision => precision.to_i, :locale=>:fr))
               }
    Redmine::Hook.call_hook(:plugin_redmine_finance_model_financesheet_deliverable_entry_to_pdf, { :financesheet => self, :deliverable_entry => deliverable_entry, :pdf_data => pdf_data})
    return pdf_data
  end

  # Array of users to find
  # String of extra conditions to add onto the query (AND)
  def conditions(users, extra_conditions=nil)
    if self.potential_deliverable_entry_ids.empty?
      if self.date_from.present? && self.date_to.present?
        conditions = ["#{IssueDeliverables.table_name}.invoiced_on >= (:from) AND #{IssueDeliverables.table_name}.invoiced_on <= (:to) AND #{IssueDeliverables.table_name}.project_id IN (:projects) AND #{IssueDeliverables.table_name}.author_id IN (:users)",
                      {
                        :from => self.date_from,
                        :to => self.date_to,
                        :projects => self.projects,
                        :users => users
                      }]
      else # All deliverable
        conditions = ["#{IssueDeliverables.table_name}.project_id IN (:projects) AND #{IssueDeliverables.table_name}.author_id IN (:users)",
                      {
                        :projects => self.projects,
                        :users => users
                      }]
      end
    else
      conditions = ["#{IssueDeliverables.table_name}.author_id IN (:users) AND #{IssueDeliverables.table_name}.id IN (:potential_deliverable_entries)",
                    {
                      :users => users,
                      :potential_deliverable_entries => self.potential_deliverable_entry_ids
                    }]
    end

    if extra_conditions
      conditions[0] = conditions.first + ' AND ' + extra_conditions
    end
      
    Redmine::Hook.call_hook(:plugin_redmine_finance_model_financesheet_conditions, { :financesheet => self, :conditions => conditions})
    return conditions
  end

  def includes
    includes = [:project, :deliverable, {:issue => [:tracker, :author, :priority]}]
    Redmine::Hook.call_hook(:plugin_redmine_finance_model_financesheet_includes, { :financesheet => self, :includes => includes})
    return includes
  end  




########################################## PRIVATE #########################################
  private

  
  def deliverable_entries_for_all_users(project)
    deliverables =  project.deliverables.find(:all,
                                     :conditions => self.conditions(self.users),
                                     :include => self.includes,
                                     :order => "#{IssueDeliverables.table_name}.invoiced_on ASC")
      
    return deliverables
  end
  
  def deliverable_entries_for_current_user(project)
    return project.deliverables.find(:all,
                                     :conditions => self.conditions(User.current.id),
                                     :include => self.includes,
                                     :include => [:deliverable, {:issue => [:tracker, :author, :priority]}],
                                     :order => "#{IssueDeliverables.table_name}.invoiced_on ASC")
  end
  
  def issue_deliverable_entries_for_all_users(issue)
    return issue.deliverables.find(:all,
                                   :conditions => self.conditions(self.users),
                                   :include => self.includes,
                                   :include => [:deliverable,{:issue => [:author]}],
                                   :order => "#{IssueDeliverables.table_name}.invoiced_on ASC")
  end
  
  def issue_deliverable_entries_for_current_user(issue)
    return issue.deliverables.find(:all,
                                   :conditions => self.conditions(User.current.id),
                                   :include => self.includes,
                                   :include => [:deliverable,{:issue => [:author]}],
                                   :order => "#{IssueDeliverables.table_name}.invoiced_on ASC")
  end
  
  def deliverable_entries_for_user(user, options={})
    extra_conditions = options.delete(:conditions)
    
    return IssueDeliverables.find(:all,
                          :conditions => self.conditions([user], extra_conditions),
                          :include => self.includes,
                          :order => "#{IssueDeliverables.table_name}.invoiced_on ASC"
                          )
  end
  
  def fetch_deliverable_entries_by_project
    self.projects.each do |project|
      logs = []
      users = []
      if User.current.admin?
        # Administrators can see all deliverable entries
        logs = deliverable_entries_for_all_users(project)
        users = logs.collect(&:author).uniq.sort
      elsif User.current.allowed_to_on_single_potentially_archived_project?(:see_project_financesheets, project)
        # Users with the Role and correct permission can see all deliverable entries
        logs = deliverable_entries_for_all_users(project)
        users = logs.collect(&:author).uniq.sort
      elsif User.current.allowed_to_on_single_potentially_archived_project?(:view_deliverable_entries, project)
        # Users with permission to see their deliverable entries
        logs = deliverable_entries_for_current_user(project)
        users = logs.collect(&:author).uniq.sort
      else
        # Rest can see nothing
      end
      
      # Append the parent project name
      if project.parent.nil?
        unless logs.empty?
          self.deliverable_entries[project.name] = { :logs => logs, :users => users }
        end
      else
        unless logs.empty?
          self.deliverable_entries[project.parent.name + ' / ' + project.name] = { :logs => logs, :users => users }
        end
      end
    end
  end
  
  def fetch_deliverable_entries_by_user
    self.users.each do |user_id|
      logs = []
      if User.current.admin?
        # Administrators can see all deliverable entries
        logs = deliverable_entries_for_user(user_id)
      elsif User.current.id == user_id
        # Users can see their own their deliverable entries
        logs = deliverable_entries_for_user(user_id)
      elsif User.current.allowed_to_on_single_potentially_archived_project?(:see_project_financesheets, nil, :global => true)
        # User can see project financesheets in at least once place, so
        # fetch the user deliverablelogs for those projects
        logs = deliverable_entries_for_user(user_id, :conditions => Project.allowed_to_condition(User.current, :see_project_financesheets))
      else
        # Rest can see nothing
      end
      
      unless logs.empty?
        user = User.find_by_id(user_id)
          
        self.deliverable_entries[user.name] = { :logs => logs } unless user.nil?
      end
    end
  end
  
  # project => { :users => [users shown in logs],
  # :issues =>
  # { issue => {:logs => [deliverable entries],
  # issue => {:logs => [deliverable entries],
  # issue => {:logs => [deliverable entries]}
  #
  def fetch_deliverable_entries_by_issue
    self.projects.each do |project|
      logs = []
      users = []
      project.issues.each do |issue|
        if User.current.admin?
          # Administrators can see all deliverable entries
          logs << issue_deliverable_entries_for_all_users(issue)
        elsif User.current.allowed_to_on_single_potentially_archived_project?(:see_project_financesheets, project)
          # Users with the Role and correct permission can see all deliverable entries
          logs << issue_deliverable_entries_for_all_users(issue)
        elsif User.current.allowed_to_on_single_potentially_archived_project?(:view_deliverable_entries, project)
          # Users with permission to see their deliverable entries
          logs << issue_deliverable_entries_for_current_user(issue)
        else
          # Rest can see nothing
        end
      end

      logs.flatten! if logs.respond_to?(:flatten!)
      logs.uniq! if logs.respond_to?(:uniq!)
      
      unless logs.empty?
        users << logs.collect(&:author).uniq.sort

        
        issues = logs.collect(&:issue).uniq
        issue_logs = { }
        issues.each do |issue|
          issue_logs[issue] = logs.find_all {|deliverable_log| deliverable_log.issue == issue } # deliverable is for this issue
        end
        
        # TODO: TE without an issue
        
        self.deliverable_entries[project] = { :issues => issue_logs, :users => users}
      end
    end
  end

  def budgets_by_month()
    if( (!self.date_from.nil? && self.date_from.to_s.length > 0) && (!self.date_to.nil? && self.date_to.to_s.length > 0))
        return Budget.all( 
                    :all,
                    :conditions => ["#{Budget.table_name}.project_id IN (:projects) AND #{Budget.table_name}.period >= :from AND #{Budget.table_name}.period <= :to",
                          {
                            :projects => self.projects,
                            :from => self.date_from,
                            :to => self.date_to,
                          }],
                    :order => "#{Budget.table_name}.period ASC"
                  )
    end
    if(!self.date_from.nil? && self.date_from.to_s.length > 0)
        return Budget.all( 
                    :all,
                    :conditions => ["#{Budget.table_name}.project_id IN (:projects) AND #{Budget.table_name}.period >= :from",
                          {
                            :projects => self.projects,
                            :from => self.date_from
                          }],
                    :order => "#{Budget.table_name}.period ASC"
                  )
    end
    if(!self.date_to.nil? && self.date_to.to_s.length > 0)
        return Budget.all( 
                    :all,
                    :conditions => ["#{Budget.table_name}.project_id IN (:projects) AND #{Budget.table_name}.period <= :to",
                          {
                            :projects => self.projects,
                            :to => self.date_to
                          }],
                    :order => "#{Budget.table_name}.period ASC"
                  )
    end
    
    return Budget.all( 
                    :all,
                    :conditions => ["#{Budget.table_name}.project_id IN (:projects)",
                          {
                            :projects => self.projects
                          }],
                    :order => "#{Budget.table_name}.period ASC"
                  )
  end
  
  def fetch_budgets_entries_by_month()
    budgets = budgets_by_month()
    
    budget_by_month ={}
    

    budgets.each do |budget|
      
      key = budget.period.strftime("%Y%m")
      # TODO rewrite that code
      if !budget.project.parent.nil? && self.sort == :project
        key =  budget.project.parent.name + ' / ' + budget.project.name + "~" + key.to_s
      else
        key =  budget.project.to_s + "~" + key.to_s
      end        
        
      if(budget_by_month[key].nil?)
        budget_by_month[key]=0
      end
      
      budget_by_month[key] += budget.amount
    end
    
    budget_by_month
  end
  
  def fetch_budgets_entries_by_year()
    
    budgets = budgets_by_month()
    
    budget_by_year ={}
    
    budgets.each do |budget|
      
      
      key = budget.period.year.to_s
      # TODO rewrite that code
      if !budget.project.parent.nil? && self.sort == :project
        key =  budget.project.parent.name + ' / ' + budget.project.name + "~" + key.to_s
      else
        key =  budget.project.to_s + "~" + key.to_s
      end
      
      if(budget_by_year[key].nil?)
        budget_by_year[key] = 0
      end
      budget_by_year[key] += budget.amount
      
    end
    
    budget_by_year
    
  end
  
  def fetch_budgets_entries_by_week()
    
    budgets = budgets_by_month()
    
    budget_by_week = {}
    
    budgets.each do |budget|
        
        #nb day by month
        _day_in_month = days_in_month(budget.period.year, budget.period.month)
       
        _first_date_of_month = Date.civil(budget.period.year, budget.period.month, 1)
        _last_day_of_month = Date.civil(budget.period.year, budget.period.month, _day_in_month)
        
        # budget by day
        _bbd = budget.amount / _day_in_month
        
        _date_from = _first_date_of_month
     
       ## the first day of the 
       _date_from = _date_from - (_first_date_of_month.cwday - 1)%7
       
       while _date_from <= _last_day_of_month
         
           #determine the number of day in this week
          _date_to = _date_from + 6
           
          # test if the week start before the begin of the month
          if(_date_from < _first_date_of_month)
            _date_from = _first_date_of_month
          end
           
          # test if the week and after the end of the monthe
          if(_date_to > _last_day_of_month)
            _date_to = _last_day_of_month
          end
           
          _nb_day_week = _date_to - _date_from
           
          key= _date_to.strftime("%Y%W")
          
          # TODO rewrite that code
          if !budget.project.parent.nil? && self.sort == :project
            key =  budget.project.parent.name + ' / ' + budget.project.name + "~" + key.to_s
          else
            key =  budget.project.to_s + "~" + key.to_s
          end
          
          if(budget_by_week[key].nil?)
            budget_by_week[key]=0
          end
          budget_by_week[key] += _bbd * _nb_day_week
          
          _date_from = _date_to + 1

        end
    end
     
    budget_by_week
    
  end

  def l(*args)
    I18n.t(*args)
  end
  
  def days_in_month(year, month)
    (Date.new(year, 12, 31) << (12-month)).day
  end
  
  def initpage(mypdf)
    myFont = 'Helvetica'
    #titles table
    t = ['#','date',l(:label_member),l(:label_project),l(:label_issue),"#{l(:label_issue)} #{l(:field_subject)}",l(:label_issue_status),l(:field_description),l(:label_deliverable_name),l(:label_deliverable_amount)]
    #colum_size table
    cs = [10,20,20,20,20,30,20,87,30,20] 
    #colum header height
    ch = 6
    #data height
    dh = 6
    mypdf.AliasNbPages
    mypdf.AddPage()
    
#Titre
    #Sélection de la police
    mypdf.SetFont(myFont,'B',14)
    #Texte centré dans une cellule 20*10 mm encadrée et retour à la ligne
    mypdf.Cell(0,10,l(:financesheet_title),1,1,'C')
    mypdf.Ln
#Header du tableau
    font_size=9
    mypdf.SetFont(myFont,'B',font_size);
    mypdf.SetFillColor(230, 230, 230)
    
    #détermination du nombre de ligne maximum dans l'entete
    nb_line_size=1
    i=0
    t.each do |cell|
      s=(mypdf.GetStringWidth(cell)/cs[i]).round
      if (s>nb_line_size)
        nb_line_size=s
      end
      i=i+1
    end
    #sauvegarde des positions de départ
    x0 = mypdf.GetX()
    x1 = x0
    y1 = mypdf.GetY()
    #écriture des lignes
    i=0
    t.each do |cell|
      mypdf.Rect(mypdf.GetX(),mypdf.GetY(),cs[i],nb_line_size*font_size,'FD')
      mypdf.MultiCell(cs[i],ch,cell,0,'C')
      x1 = x1+cs[i]
      mypdf.SetXY(x1,y1)
      i=i+1
    end
    
    #on se positionne sous l'entete
    mypdf.SetXY(x0,y1+(nb_line_size)*font_size)
    return mypdf
  end
  
  def addfooter(mypdf)
    mypdf.SetFont('Helvetica','',6);
    mypdf.SetXY(0,200)
    mypdf.Cell(0,5,"Page "+mypdf.PageNo().to_s,0,1,'C')
    return mypdf
  end
end