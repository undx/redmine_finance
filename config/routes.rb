ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  #map.home '', :controller => 'welcome'
  map.home '', :controller => 'my'

  # !! perturbe le bon fonctionnement de redmine !!
  #map.connect 'projects/:project_id', :controller => "issues", :action => "index"
  
  
end
