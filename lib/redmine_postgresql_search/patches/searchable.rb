module RedminePostgresqlSearch
  module Patches
    module Searchable

      module ClassMethods

        def rebuild_index
          transaction do
            FulltextIndex.delete_all(searchable_type: name)
            find_in_batches.each do |group|
              group.each do |r|
                r.update_fulltext_index
              end
            end
          end
        end

        # overrides ActsAsSearchable
        def search_tokens_condition(columns, tokens, all_words)
          "query @@ tsv" # query is defined in fetch_ranks_and_ids
        end
        private :search_tokens_condition

        # overrides ActsAsSearchable
        def search_result_ranks_and_ids(tokens, user=User.current, projects=nil, options={})
          @searchable_query_sql = QueryBuilder.new(tokens, options).to_sql
          @already_found = []
          super
        end

        # overrides ActsAsSearchable
        #
        # select ..., ts_rank(tsv, query) AS score FROM fulltext_indices,
        # plainto_tsquery(query) query where query @@ tsv ORDER BY score DESC;
        def fetch_ranks_and_ids(scope, limit)

          # find out what we're up to so we are able to include the proper
          # fulltext_indices
          querying_journals      = scope.to_sql["#{Journal.table_name}.private_notes = 'f' OR"].present?
          querying_custom_fields = !querying_journals && scope.to_sql["#{CustomValue.table_name}.custom_field_id IN ("].present?
          querying_attachments   = !querying_journals && !querying_custom_fields && scope.to_sql[Attachment.table_name].present?

          searchable_id = 'searchable_id'
          scope = if querying_journals
            searchable_id = 'journalized_id'
            scope.
              includes(journals: :fulltext_index).
              references(journals: :fulltext_index)
          elsif querying_custom_fields
            searchable_id = 'customized_id'
            scope.
              includes(custom_values: :fulltext_index).
              references(custom_values: :fulltext_index)
          elsif querying_attachments
            searchable_id = 'container_id'
            scope.
              includes(attachments: :fulltext_index).
              references(attachments: :fulltext_index)
          else
            scope.
              includes(:fulltext_index).
              references(:fulltext_index)
          end

          scope = scope.
            joins(", #{@searchable_query_sql}").
            reorder('score DESC'). # see the pluck below for the declaration
            limit(limit)

          if @already_found.any?
            scope = scope.where("#{searchable_id} NOT IN (?)", @already_found)
          end
            # 1 | 32 - rank normalization by document length, see
            # http://www.postgresql.org/docs/current/static/textsearch-controls.html#TEXTSEARCH-RANKING
          scope.pluck("ts_rank(tsv, query, 1|32) as score, #{searchable_id}").tap do |result|
            result.each do |r|
              r[0] = (r[0] * 10000).to_i
              @already_found << r[1]
            end
          end

        end
        private :fetch_ranks_and_ids


        # Fetches the data needed to index the record with the given id
        #
        # TODO possible optimization:
        #
        # At the moment, data is written to DB, then, in this after_commit
        # hook, we read it back in order to push it into FulltextIndex where
        # it will be put into a to_tsvector update query.
        #
        # Ideally we could use the scope to generate the SQL for our update
        # statement so the data to be indexed never leaves the DB.
        # Problem: the scope selects from i.e. wiki_pages, the update has to
        # be update fulltext_indices ...
        def fetch_index_data(id)
          scope = (searchable_options[:scope] || self)
          scope = scope.call({}) if scope.respond_to?(:call)
          scope = scope.where(id: id)
          sql = scope.select(searchable_options[:fulltext_index_select_cols]).to_sql
          connection.execute(sql).first.tap do |r|
            r.symbolize_keys! if r
          end
        end

      end


      module InstanceMethods

        def update_fulltext_index
          return if !add_to_index? or project_id.nil?
          self.fulltext_index ||= FulltextIndex.create(searchable: self, project_id: self.project_id)

          self.fulltext_index.update_index!
        rescue
          logger.error $!
          logger.error $!.backtrace.join "\n"
        end

      end


    end
  end
end
