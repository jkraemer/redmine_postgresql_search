module RedminePostgresqlSearch
  class QueryBuilder
    def initialize(tokens, options = {})
      @tokens = tokens
      @titles_only = options[:titles_only]
      @all_words = options[:all_words]
      @fuzzy_matches = options[:fuzzy_matches]
    end

    # This is the common table expression (CTE) which does the actual full text search search.
    # It produces search results for all Searchables (ignoring visibility and everything else).
    # The result can be reused by all Searchable queries.
    def fts_cte
      'WITH fts AS' \
      " (SELECT #{ts_rank} AS score" \
      ', searchable_id' \
      ', searchable_type' \
      " FROM #{FulltextIndex.table_name}, #{ts_query}" \
      ' WHERE query @@ tsv)'
    end

    protected

    # Creates the query vector that is matched against the tsvector tsv from the search table.
    def ts_query
      FulltextIndex.send :sanitize_sql_array, [
        'to_tsquery(:config, :query) query',
        config: FulltextIndex::SEARCH_CONFIG, query: searchable_query
      ]
    end

    # Calculates the score for a search result.
    def ts_rank
      # now - (timestamp in the past or now if null)
      age = "extract(epoch from age(now(), coalesce(#{FulltextIndex.table_name}.updated_on, now())))"
      age_weight_cutoff = 0.1
      age_weight_slope = 300
      day_seconds = 60 * 60 * 24
      'ts_rank(tsv, query, 1|32) *' \
      " greatest(exp(-#{age} / #{day_seconds} / #{age_weight_slope}), #{age_weight_cutoff})"
    end

    # Builds the fts query string for Postgres.
    def searchable_query
      tokens = if @all_words
                 op = '&'
                 @tokens
               else
                 op = '|'
                 @fuzzy_matches + @tokens
               end

      if @titles_only
        tokens.map { |token| "#{token}:A" }
      else
        tokens
      end.join(op)
    end
  end
end
