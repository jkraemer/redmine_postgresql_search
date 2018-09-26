module RedminePostgresqlSearch
  def self.setup
    Rails.logger.info 'enabling advanced PostgreSQL search'

    SearchController.class_eval do
      prepend Patches::SearchController
    end

    Redmine::Search::Fetcher.class_eval do
      prepend Patches::Fetcher
    end

    @searchables = []

    setup_searchable Attachment,
                     mapping: { a: :filename, b: :description },
                     project_id: -> { container.project_id if container.respond_to?(:project_id) },
                     updated_on: -> { created_on }

    setup_searchable Changeset,
                     mapping: { b: :comments },
                     project_id: -> { repository.project_id if repository.present? },
                     updated_on: -> { committed_on }

    setup_searchable CustomValue,
                     if: -> { customized.is_a?(Issue) },
                     mapping: { b: :value },
                     project_id: -> { customized.project_id if customized.present? },
                     updated_on: -> { customized.updated_on if customized.present? }

    setup_searchable Document,
                     mapping: { a: :title, b: :description },
                     updated_on: -> { created_on }

    setup_searchable Issue,
                     mapping: { a: :subject, b: :description }

    setup_searchable Journal,
                     mapping: { b: :notes, c: -> { journalized.subject if journalized.is_a?(Issue) } },
                     project_id: -> { journalized.project_id if journalized.present? },
                     updated_on: -> { created_on }

    setup_searchable Message,
                     mapping: { a: :subject, b: :content }

    setup_searchable News,
                     mapping: { a: :title, b: :summary, c: :description },
                     updated_on: -> { created_on }

    setup_searchable WikiPage,
                     mapping: { a: :title, b: -> { content.text if content.present? } },
                     project_id: -> { wiki.project_id if wiki.present? },
                     updated_on: -> { content.updated_on if content.present? }

    load 'redmine_postgresql_search/test_support.rb' if Rails.env.test?
  end

  def self.settings
    if Rails.version >= '5.2'
      Setting[:plugin_redmine_postgresql_search]
    else
      ActionController::Parameters.new(Setting[:plugin_redmine_postgresql_search])
    end
  end

  def self.setting?(value)
    return true if settings[value].to_i == 1

    false
  end

  def self.rebuild_indices
    @searchables.each(&:rebuild_index)
  end

  def self.setup_searchable(clazz, options = {})
    @searchables << clazz
    clazz.class_eval do
      has_one :fulltext_index, as: :searchable, dependent: :delete
      if (condition = options[:if])
        define_method :add_to_index? do
          !!(instance_exec(&condition))
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

      if (getter = options[:project_id])
        define_method :project_id do
          instance_exec(&getter)
        end
      end

      if (getter = options[:updated_on])
        define_method :updated_on do
          instance_exec(&getter)
        end
      end
      prepend RedminePostgresqlSearch::Patches::Searchable::InstanceMethods
      extend RedminePostgresqlSearch::Patches::Searchable::ClassMethods
    end
  end
end
