module RedminePostgresqlSearch
  module Patches
    module Fetcher

      # override the original initialize for different token parsing:
      #
      # keep trailing * to trigger prefix queries
      # allow any number of tokens of any length
      def initialize(question, user, scope, projects, options={})
        super

        # extract tokens from the question
        # eg. hello "bye bye" => ["hello", "bye bye"]
        @tokens = @question.scan(%r{((\s|^)"[^"]+"(\s|$)|\S+)}).collect {|m| m.first.gsub(%r{(^\s*"\s*|\s*"\s*$)}, '')}
        @tokens.uniq!
      end
    end
  end
end
