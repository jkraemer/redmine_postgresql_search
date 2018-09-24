module RedminePostgresqlSearch
  module Patches
    module Fetcher
      # override the original initialize for different token parsing:
      # allow any number of tokens of any length
      def initialize(question, user, scope, projects, options = {})
        super
        @tokens = Tokenizer.build_tokens(@question)
        return if options[:all_words] || @tokens.blank?

        # create additional search tokens by querying a word table for fuzzy matches
        # the <% operator selects words with at least 60% word similarity (see PostgreSQL's pg_trgm docs)
        sql = 'SELECT word FROM fulltext_words WHERE ' + @tokens.map { |t| "'#{t}' <% word" }.join(' OR ')
        @options[:fuzzy_matches] = ActiveRecord::Base.connection.execute(sql).field_values('word')
      end
    end
  end
end
