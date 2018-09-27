class AddSearchFunctions < Rails.version < '5.2' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  include RedminePostgresqlSearch::Migration

  def up
    execute_sql_file 'search_functions_up'
  end

  def down
    execute_sql_file 'search_functions_down'
  end
end
