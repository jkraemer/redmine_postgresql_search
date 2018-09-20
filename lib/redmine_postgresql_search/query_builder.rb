module RedminePostgresqlSearch
  class QueryBuilder
    def initialize(tokens, options = {})
      @tokens = tokens
      @titles_only = options[:titles_only]
      @all_words = options[:all_words]
      @fuzzy_matches = options[:fuzzy_matches]
    end

    def to_sql
      # sql to create the query vector that is matched against the tsv
      FulltextIndex.send :sanitize_sql_array, [
        'to_tsquery(:config, :query) query',
        config: FulltextIndex::SEARCH_CONFIG, query: searchable_query
      ]
    end

    private

    def searchable_query
      if @all_words
        op = '&'
        tokens = @tokens
      else
        op = '|'
        tokens = @fuzzy_matches + @tokens
      end
      if @titles_only
        tokens.map { |token| "#{token}:A" }
      else
        tokens
      end.join(op)
    end
  end
end
