module RedminePostgresqlSearch
  module Patches
    module Searchable
      module ClassMethods
        def rebuild_index
          transaction do
            FulltextIndex.where(searchable_type: name).delete_all
            find_in_batches.each do |group|
              group.each(&:update_fulltext_index)
            end
          end
        rescue StandardError => e
          logger.error("rebuild index failed for searchable type #{name}")
          raise e
        end

        # overrides ActsAsSearchable
        def search_tokens_condition(_columns, _tokens, _all_words)
          'query @@ tsv' # query is defined in fetch_ranks_and_ids
        end

        # overrides ActsAsSearchable
        def search_result_ranks_and_ids(tokens, user = User.current, projects = nil, options = {})
          @searchable_query_sql = QueryBuilder.new(tokens, options).to_sql
          @already_found = []
          super
        end

        # overrides ActsAsSearchable
        #
        # select ..., ts_rank(tsv, query) AS score FROM fulltext_indices,
        # to_tsquery(query) query where query @@ tsv ORDER BY score DESC;
        def fetch_ranks_and_ids(scope, limit)
          # find out what we're up to so we are able to include the proper
          # fulltext_indices
          querying_journals      = scope.to_sql["#{Journal.table_name}.private_notes = 'f' OR"].present?
          querying_custom_fields = !querying_journals && scope.to_sql["#{CustomValue.table_name}.custom_field_id IN ("].present?
          querying_attachments   = !querying_journals && !querying_custom_fields && scope.to_sql[Attachment.table_name].present?

          searchable_id = 'searchable_id'
          scope = if querying_journals
                    searchable_id = 'journalized_id'
                    scope.includes(journals: :fulltext_index)
                         .references(journals: :fulltext_index)
                  elsif querying_custom_fields
                    searchable_id = 'customized_id'
                    scope.includes(custom_values: :fulltext_index)
                         .references(custom_values: :fulltext_index)
                  elsif querying_attachments
                    searchable_id = 'container_id'
                    scope.includes(attachments: :fulltext_index)
                         .references(attachments: :fulltext_index)
                  else
                    scope.includes(:fulltext_index)
                         .references(:fulltext_index)
                  end

          scope = scope.joins(", #{@searchable_query_sql}")
                       .reorder('score DESC')
                       .limit(limit) # see the pluck below for the declaration

          @already_found.any? && scope = scope.where("#{searchable_id} NOT IN (?)", @already_found)

          # 1 | 32 - rank normalization by document length, see
          # http://www.postgresql.org/docs/current/static/textsearch-controls.html#TEXTSEARCH-RANKING
          # ts_rank is scaled depending on searchable age (updated_on) with the function e^(-age / 500) with a minimum of 0.1
          scope.pluck(Arel.sql(['ts_rank(tsv, query, 1|32)' \
                ' * greatest(exp(extract(epoch from age(coalesce(fulltext_indices.updated_on, now()), now())) / 86400 / 300), 0.1)' \
                ' as score', searchable_id].join(', '))).tap do |result|
            result.each do |r|
              r[0] = (r[0] * 10_000).to_i
              @already_found << r[1]
            end
          end
        end
      end

      module InstanceMethods
        def update_fulltext_index
          return unless add_to_index?

          unless fulltext_index.present? && fulltext_index.destroyed?
            project_id = try(:project_id)
            updated_on = try(:updated_on)
            if fulltext_index.present?
              fulltext_index.update(project_id: project_id, updated_on: updated_on)
            elsif fulltext_index.blank?
              self.fulltext_index = FulltextIndex.create(searchable: self, project_id: project_id, updated_on: updated_on)
            end
          end
          fulltext_index.update_index!
        end
      end
    end
  end
end
