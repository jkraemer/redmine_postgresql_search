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
        scope_options = {}

        @scopes_without_postgresql_search = []

        @scope.each do |scope|
          klass = scope.singularize.camelcase.constantize
          unless klass.respond_to?(:search_queries)
            Rails.logger.info("PostgreSQL search not configured for class #{klass.name}")
            @scopes_without_postgresql_search << scope
            next
          end
          queries_with_scope += klass.search_queries(@tokens, User.current, @projects, @options).map { |q| [scope, q] }
          scope_options[scope] = {}
          scope_options[scope][:last_modification_field] = klass.last_modification_field
        end

        pg_matches =
          if queries_with_scope.present?
            sql = @query_builder.search_sql(queries_with_scope, scope_options)
            result = ActiveRecord::Base.connection.execute(sql)
            # with Redmine 3, id is returned as a string
            # with Redmine 4, an int is returned
            result.each_row.map { |scope, id| [scope, id.to_i] }
          else
            []
          end
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
