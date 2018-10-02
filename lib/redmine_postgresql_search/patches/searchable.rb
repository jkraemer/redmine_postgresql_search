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

        # Build search queries for searchable type.
        # Can return multiple queries when journals, attachments and custom fields are searched, too.
        # The queries expect a CTE called 'fts' which returns a searchable_type and a searchable_id.
        def search_queries(_tokens, user = User.current, projects = nil, options = {})
          projects = [] << projects if projects.is_a?(Project)
          r = []
          limit = options[:limit]

          unless options[:attachments] == 'only'
            r << search_scope(user, projects, options)
                 .joins(cte_join_cond)
                 .limit(limit)

            if !options[:titles_only] && searchable_options[:search_custom_fields]
              searchable_custom_fields = CustomField.where(type: "#{name}CustomField", searchable: true).to_a
              if searchable_custom_fields.any?
                fields_by_visibility = searchable_custom_fields.group_by do |field|
                  field.visibility_by_project_condition(searchable_options[:project_key], user, "#{CustomValue.table_name}.custom_field_id")
                end
                clauses = []
                fields_by_visibility.each do |visibility, fields|
                  clauses << "(#{CustomValue.table_name}.custom_field_id IN (#{fields.map(&:id).join(',')}) AND (#{visibility}))"
                end
                visibility = clauses.join(' OR ')
                r << search_scope(user, projects, options)
                     .joins(:custom_values)
                     .joins(cte_join_cond(CustomValue))
                     .where(visibility)
                limit(limit)
              end
            end

            if !options[:titles_only] && searchable_options[:search_journals]
              r << search_scope(user, projects, options)
                   .joins(:journals)
                   .joins(cte_join_cond(Journal))
                   .where("#{Journal.table_name}.private_notes = ? OR (#{Project.allowed_to_condition(user, :view_private_notes)})", false)
                   .limit(limit)
            end
          end

          if searchable_options[:search_attachments] &&
             (options[:titles_only] ? options[:attachments] == 'only' : options[:attachments] != '0')
            r << search_scope(user, projects, options)
                 .joins(:attachments)
                 .joins(cte_join_cond(Attachment))
                 .limit(limit)
          end
          r
        end

        protected

        # joins the search scope to the common table expression which does the actual full text search
        def cte_join_cond(model_class = self)
          "JOIN fts ON #{model_class.table_name}.id = fts.searchable_id AND searchable_type = '#{model_class.name}'"
        end
      end

      module InstanceMethods
        def update_fulltext_index
          return unless add_to_index?

          unless (fulltext_index.present? && fulltext_index.destroyed?) || fulltext_index.present?
            self.fulltext_index = FulltextIndex.create(searchable: self)
          end
          fulltext_index.update_index!
        end
      end
    end
  end
end
