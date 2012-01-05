class DeliverablesController < ApplicationController
  layout 'admin'
  
  before_filter :require_admin
  before_filter :get_precision

  verify :method => :post, :only => [ :destroy],
         :redirect_to => { :action => :index }

  def index
    @deliverable_pages, @deliverables = paginate :deliverables, :per_page => 25
    render :action => "index", :layout => false if request.xhr?
  end

  def new
    @trackers = Tracker.all
    @deliverable = Deliverable.new(params[:deliverable])
    if request.post?
      
      if @deliverable.save
        # workflow copy
        if !params[:copy_workflow_from].blank? && (copy_from = deliverable.find_by_id(params[:copy_workflow_from]))
          @deliverable.workflows.copy(copy_from)
        end
        flash[:notice] = l(:notice_successful_create)
        redirect_to :action => 'index'
      end
    end
  end

  def edit
    @trackers = Tracker.all
    @deliverable = Deliverable.find(params[:id])
    if request.post? and @deliverable.update_attributes(params[:deliverable])
      flash[:notice] = l(:notice_successful_update)
      redirect_to :action => 'index'
    end
  end
  
  def show
    @trackers = Tracker.all
    @deliverable = Deliverable.find(params[:id])
    
  end

  def destroy
    @deliverable = Deliverable.find(params[:id])
    unless @deliverable.deliverables.empty?
      flash[:error] = l(:error_can_not_delete_deliverable)
    else
      if @deliverable.destroy
        flash[:notice] = l(:notice_successful_delete_delivrable)
      end
    end
    redirect_to :action => 'index'
  end
  
  def preview
        
    @text = (params[:deliverable] ? params[:deliverable][:description] : nil)
    render :partial => 'deliverables/preview'
  end
  
  def update
    @deliverable = Deliverable.find(params[:id])
    
    if @deliverable.update_attributes(params[:deliverable])
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = l(:error_can_not_update_deliverable)
    end
    redirect_to :action => 'index'

  end
  
  private
  
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
