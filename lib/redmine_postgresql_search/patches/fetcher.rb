module RedminePostgresqlSearch
  module Patches
    module Fetcher
      # override the original initialize for different token parsing:
      # allow any number of tokens of any length
      def initialize(question, user, scope, projects, options = {})
        super
        @tokens = Tokenizer.build_tokens(@question)
        return if @tokens.blank? # nothing to do
        @query_builder = QueryBuilder.new(@tokens, @options)
      end

      def load_result_ids
        return [] if @tokens.blank?

        queries_with_scope = []

        @scopes_without_postgresql_search = []

        @scope.each do |scope|
          klass = scope.singularize.camelcase.constantize
          unless klass.respond_to?(:search_queries)
            Rails.logger.info("PostgreSQL search not configured for class #{klass.name}")
            @scopes_without_postgresql_search << scope
            next
          end
          queries_with_scope += klass.search_queries(@tokens, User.current, @projects, @options).map { |q| [scope, q] }
        end

        union_sql = queries_with_scope.map { |scope, q| q.select(:id, :score, "'#{scope}' AS scope").to_sql }.join(' UNION ')
        subquery_sql = [union_sql, 'ORDER BY score DESC'].join("\n")

        limit = @options[:limit]
        limit_sql = "LIMIT #{limit}" if limit
        sql = [@query_builder.fts_cte,
               "SELECT scope, id FROM (SELECT DISTINCT ON (scope, id) scope, id, score FROM (#{subquery_sql}) q ) q2",
               'ORDER BY q2.score DESC, id',
               limit_sql].compact.join("\n")
        result = ActiveRecord::Base.connection.execute(sql)
        # with Redmine 3, id is returned as a string
        # with Redmine 4, an int is returned
        pg_matches = result.each_row.map { |scope, id| [scope, id.to_i] }
        # Use Redmine's default search as fallback if a type has no config for Postgres
        # and append them to the PostgreSQL fts search results.
        # This means that other results will be ranked lower than all fts results.
        @scope = @scopes_without_postgresql_search
        other_matches = super
        results = pg_matches + other_matches
        results
      end
    end
  end
end
