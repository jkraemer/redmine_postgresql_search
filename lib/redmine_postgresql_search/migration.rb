module RedminePostgresqlSearch
  module Migration
    def execute_sql_file(name)
        sql = File.read(File.join(File.dirname(__FILE__), '../../db/migrate', name + '.sql'))
        execute(sql)
    end
  end
end
