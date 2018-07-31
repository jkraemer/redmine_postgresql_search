module RedminePostgresqlSearch
  class QueryBuilder
    def initialize(tokens, options = {})
      @tokens = tokens
      @titles_only = options[:titles_only]
      @all_words = options[:all_words]
    end

    def to_sql
      # sql to create the query vector that is matched against the tsv
      FulltextIndex.send :sanitize_sql_array, [
        'to_tsquery(:config, :query) query',
        config: FulltextIndex::SEARCH_CONFIG, query: searchable_query
      ]
    end

    private

    def sanitized_tokens
      Tokenizer.sanitize_query_tokens @tokens
    end

    def searchable_query
      if @all_words
        if @titles_only
          sanitized_tokens.map { |token| "#{token}:A" }
        else
          sanitized_tokens
        end.join ' & '
      else
        sanitized_tokens.map do |token|
          sql = "SELECT word FROM fulltext_words WHERE '#{token}' <% word"
          fuzzy_matches = ActiveRecord::Base.connection.execute(sql).field_values('word')

          query_words =
            if @titles_only
              fuzzy_matches.map { |word| "#{word}:A" } + [token + ':A']
            else
              fuzzy_matches + [token]
            end
          query_words
        end.flatten.join '|'
      end
    end
  end
end
