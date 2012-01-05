module BudgetsHelper
  
    def get_budget_vs_actual
    sql = "      SELECT
          t.seq,
          t.period,
          sum(t.budget) as budget,
          sum(t.actual) as actual
      FROM
      (
          SELECT 
          DATE_FORMAT(period,'%Y%m') as seq,
          DATE_FORMAT(period,'%M %Y') as period,
          sum( amount) as budget,
          0 as actual
          FROM budgets
          GROUP BY 1, 2
      
      UNION
          SELECT 
          DATE_FORMAT(i.due_date,'%Y%m') as seq,
          DATE_FORMAT(i.due_date,'%M %Y') as period,
          0 as budget,
          sum( idl.amount) as actual
          FROM issue_deliverables idl
          INNER JOIN issues i ON (idl.issue_id = i.id and idl.project_id = i.project_id)
          GROUP BY 1, 2
      ) t
      GROUP BY t.seq, t.period
      ORDER BY t.seq, t.period"
      
      ActiveRecord::Base.connection.select_all(sql)
  end
  
end
