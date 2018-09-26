module RedminePostgresqlSearch
  module Patches
    module SearchControllerPatch
      module InstanceMethods
        def index
          # all words is disabled by default
          params[:all_words] = '' unless params[:all_words] || RedminePostgresqlSearch.setting?(:all_words_by_default)
          super
        end
      end
    end
  end
end
