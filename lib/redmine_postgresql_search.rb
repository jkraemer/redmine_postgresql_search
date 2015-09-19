module RedminePostgresqlSearch

  SEARCHABLES = []
  def self.setup
    Rails.logger.info 'enabling advanced PostgreSQL search'
    Redmine::Search::Fetcher.class_eval do
      prepend Patches::Fetcher
    end

    setup_searchable Attachment,
      mapping: { a: :filename, b: :description },
      project_id: ->{ container.project_id }

    setup_searchable Changeset,
      mapping: { b: :comments },
      project_id: ->{ repository.project_id }

    setup_searchable CustomValue,
      if: ->{ Issue === customized },
      mapping: { b: :value },
      project_id: ->{ customized.project_id }

    setup_searchable Document,
      mapping: { a: :title, b: :description }

    setup_searchable Issue,
      mapping: { a: :subject, b: :description }

    setup_searchable Journal,
      mapping: { b: :notes, c: -> { journalized.subject } },
      project_id: ->{ journalized.project_id }

    setup_searchable Message,
      mapping: { a: :subject, b: :content }

    setup_searchable News,
      mapping: { a: :title, b: :summary, c: :description }

    setup_searchable Project,
      mapping: { a: [ :name, :identifier ], b: :description },
      project_id: ->{ self }

    setup_searchable WikiPage,
      mapping: { a: :title, b: ->{ content.text } },
      project_id: -> { wiki.project_id }


    load 'redmine_postgresql_search/test_support.rb' if Rails.env.test?
  end

  def self.rebuild_indices
    SEARCHABLES.each do |clazz|
      clazz.rebuild_index
    end
  end


  def self.setup_searchable(clazz, options = {})
    SEARCHABLES << clazz
    clazz.class_eval do
      has_one :fulltext_index, as: :searchable, dependent: :delete
      if condition = options[:if]
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
      if getter = options[:project_id]
        define_method :project_id do
          instance_exec &getter
        end
      end

      prepend RedminePostgresqlSearch::Patches::Searchable::InstanceMethods
      extend RedminePostgresqlSearch::Patches::Searchable::ClassMethods
    end
  end

end

