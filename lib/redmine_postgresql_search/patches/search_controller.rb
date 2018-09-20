module RedminePostgresqlSearch
  module Patches
    module SearchController
      def index
        # all words is disabled by default
        params[:all_words] = '' unless params[:all_words] || Setting.plugin_redmine_postgresql_search['all_words_by_default'].to_i == 1
        super
      end
    end
  end
end
