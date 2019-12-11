module RedminePostgresqlSearch
  class << self
    def setup
      Rails.logger.info 'enabling advanced PostgreSQL search'

      SearchController.class_eval do
        prepend RedminePostgresqlSearch::Patches::SearchController
      end

      Redmine::Search::Fetcher.class_eval do
        prepend RedminePostgresqlSearch::Patches::Fetcher
      end

      @searchables = []

      setup_searchable Changeset,
                       mapping: { b: :comments },
                       last_modification_field: "#{Changeset.table_name}.committed_on"

      setup_searchable Document,
                       mapping: { a: :title, b: :description },
                       last_modification_field: "#{Document.table_name}.created_on"

      setup_searchable Issue,
                       mapping: { a: :subject, b: :description }

      setup_searchable Message,
                       mapping: { a: :subject, b: :content }

      setup_searchable News,
                       mapping: { a: :title, b: :summary, c: :description },
                       last_modification_field: "#{News.table_name}.created_on"

      setup_searchable WikiPage,
                       mapping: { a: :title, b: -> { content.text if content.present? } },
                       last_modification_field: "#{WikiContent.table_name}.updated_on"

      # Searchables that depend on another Searchable and cannot be searched separately.
      # They use the last modification field of their parents.

      setup_searchable Attachment,
                       mapping: { a: :filename, b: :description }

      setup_searchable CustomValue,
                       if: -> { customized.is_a?(Issue) },
                       mapping: { b: :value }

      setup_searchable Journal,
                       mapping: { b: :notes, c: -> { journalized.subject if journalized.is_a?(Issue) } }

      load 'redmine_postgresql_search/test_support.rb' if Rails.env.test?
    end

    def settings
      Additionals.settings_compatible(:plugin_redmine_postgresql_search)
    end

    def setting?(value)
      Additionals.true?(settings[value])
    end

    def rebuild_indices
      @searchables.each(&:rebuild_index)
    end

    private

    def setup_searchable(clazz, options = {})
      @searchables << clazz
      clazz.class_eval do
        has_one :fulltext_index, as: :searchable, dependent: :delete
        if (condition = options[:if])
          define_method :add_to_index? do
            !!instance_exec(&condition)
          end
        else
          define_method :add_to_index? do
            true
          end
        end
        after_commit :update_fulltext_index

        define_method :index_data do
          Tokenizer.new(self, options[:mapping]).index_data
        end

        last_modification_field = options[:last_modification_field].presence || clazz.table_name + '.updated_on'

        define_singleton_method :last_modification_field do
          last_modification_field
        end

        prepend RedminePostgresqlSearch::Patches::Searchable::InstanceMethods
        extend RedminePostgresqlSearch::Patches::Searchable::ClassMethods
      end
    end
  end
end
