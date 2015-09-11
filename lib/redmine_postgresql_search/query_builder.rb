module RedminePostgresqlSearch
  class QueryBuilder

    def initialize(tokens, options = {})
      @tokens = tokens
      @titles_only = options[:titles_only]
      @operator = options[:all_words] ? ' & ' : ' | '
    end

    def to_sql
      # sql to create the query vector that is matched against the tsv
      FulltextIndex.send :sanitize_sql_array, [
        "to_tsquery(:config, :query) query",
        config: FulltextIndex.lanuage_config, query: searchable_query
      ]
    end

    private

    def sanitized_tokens
      Tokenizer.sanitize_query_tokens @tokens
    end

    def searchable_query
      sanitized_tokens.map do |token|
        if token.ends_with?('*')
          # prefix search
          token.sub!(/\*\z/, '')
          if @titles_only
            "#{token}:*A"
          else
            "(#{FulltextIndex::WEIGHTS.map{|w| "#{token}:*#{w}"}.join(" | ")})"
          end
        else
          @titles_only ? "#{token}:A" : token
        end
      end.join @operator
    end


  end
end
