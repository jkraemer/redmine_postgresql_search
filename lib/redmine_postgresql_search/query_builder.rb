module RedminePostgresqlSearch
  class QueryBuilder
    # !tokens must be safe for a SQL string or you will create a possibility for SQL injection!
    def initialize(tokens, options = {})
      @tokens = tokens
      @titles_only = options[:titles_only]
      @all_words = options[:all_words]
      return if options[:all_words]

      # create additional search tokens by querying a word table for fuzzy matches
      # the <% operator selects words with at least 60% word similarity (see PostgreSQL's pg_trgm docs)
      sql = 'SELECT word FROM fulltext_words WHERE ' + @tokens.map { |t| "'#{t}' <% word" }.join(' OR ')
      @fuzzy_matches = ActiveRecord::Base.connection.execute(sql).field_values('word')
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
      day_seconds = 60 * 60 * 24
      age_weight_lifetime = RedminePostgresqlSearch.settings[:age_weight_lifetime] || 365
      age_weight_min = RedminePostgresqlSearch.settings[:age_weight_min] || 0.1
      'ts_rank(tsv, query, 1|32) *' \
      " greatest(exp(-#{age} / #{day_seconds} / #{age_weight_lifetime}), #{age_weight_min})"
    end

    # Builds the fts query string for Postgres.
    def searchable_query
      if @all_words
        op = '&'
        tokens = @tokens
      else
        op = '|'
        tokens = @fuzzy_matches.present? ? @fuzzy_matches + @tokens : @tokens
      end

      if @titles_only
        tokens.map { |token| "#{token}:A" }
      else
        tokens
      end.join(op)
    end
  end
end
