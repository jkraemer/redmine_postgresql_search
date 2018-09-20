module RedminePostgresqlSearch
  module Patches
    module Fetcher
      # override the original initialize for different token parsing:
      # keep trailing * to trigger prefix queries
      # allow any number of tokens of any length
      def initialize(question, user, scope, projects, options = {})
        super

        # extract tokens from the question
        # eg. hello "bye bye" => ["hello", "bye bye"]
        @tokens = @question.scan(/((\s|^)"[^"]+"(\s|$)|\S+)/).collect { |m| m.first.gsub(/(^\s*"\s*|\s*"\s*$)/, '') }
        # tokens must be at least 2 characters long
        @tokens = Tokenizer.sanitize_query_tokens(@tokens)
        @tokens = @tokens.uniq.select { |w| w.length > 1 }

        return if options[:all_words]

        # create additional search tokens by querying a word table for fuzzy matches
        # the <% operator selects words with at least 60% word similarity (see PostgreSQL's pg_trgm docs)
        sql = 'SELECT word FROM fulltext_words WHERE ' + @tokens.map { |t| "'#{t}' <% word" }.join(' OR ' )
        @options[:fuzzy_matches] = ActiveRecord::Base.connection.execute(sql).field_values('word')
      end
    end
  end
end
