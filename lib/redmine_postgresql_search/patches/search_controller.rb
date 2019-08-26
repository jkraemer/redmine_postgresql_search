module RedminePostgresqlSearch
  module Patches
    module SearchController
      def index
        # all words is disabled by default
        params[:all_words] = '' unless params[:all_words] || RedminePostgresqlSearch.setting?(:search_all_words_by_default)
        super
      end
    end
  end
end
