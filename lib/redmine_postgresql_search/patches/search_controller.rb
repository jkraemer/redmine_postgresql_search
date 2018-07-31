module RedminePostgresqlSearch
  module Patches
    module SearchController
      def index
        # all words is disabled by default
        params[:all_words] = '' unless params[:all_words]
        super
      end
    end
  end
end
