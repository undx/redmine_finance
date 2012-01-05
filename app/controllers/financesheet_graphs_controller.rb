require 'SVG/Graph/TimeSeries'


class FinancesheetGraphsController < ApplicationController


	helper IssuesHelper
	helper BudgetsHelper

	# Displays projects by total issues over time
	def budget_vs_actual_graph
	
    
    budget = params[:data_budgets]
    deliverable = params[:data_deliverables]
    view_by= params[:view_by].to_sym
        
    case view_by
      when :Year then
        x_label_format = "%Y"
        timescale_divisions = "6 months"
      when :Month then
        x_label_format = "%b %Y"
        timescale_divisions =  "2 months"
      when :Week then
        x_label_format = "%B %Y"
        timescale_divisions = "12 weeks"
    end

    budget.each_index {|i| 
          if i%2 == 1
            budget[i] = budget[i].to_i
          end
    }
    
    deliverable.each_index {|i| 
          if i%2 == 1
           deliverable[i] = deliverable[i].to_i
          end
    }
    
    graph_budget_vs_actual = SVG::Graph::TimeSeries.new({
      :area_fill => false,
      :height => 300,
      :min_y_value => 0,
      :no_css => true,
      :show_x_guidelines => false,
      :scale_x_integers => true,
      :scale_y_integers => true,
      :show_data_points => true,
      :show_data_values => false,
      :stagger_x_labels => true,
      :style_sheet => "/plugin_assets/redmine_finance/stylesheets/issue_growth.css",
      :timescale_divisions => timescale_divisions,
      :width => 720,
      :x_label_format => x_label_format,
      :y_label_format => '%€',
      :show_y_title => true,
      :y_title => l(:amount_in_currency)

    })
		
		graph_budget_vs_actual.add_data({
       :data => budget,
       :title => l(:label_budget)
		})
    graph_budget_vs_actual.add_data({
       :data => deliverable,
       :title => l(:label_deliverable)
    })

	  # Compile the graph
		headers["Content-Type"] = "image/svg+xml"
		send_data(graph_budget_vs_actual.burn, :type => "image/svg+xml", :disposition => "inline")
	end
	
end
