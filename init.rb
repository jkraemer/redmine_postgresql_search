Redmine::Plugin.register :redmine_postgresql_search do
  name 'Redmine PostgreSQL Search Plugin'
  url  'http://redmine-search.com/'
  description 'This plugin adds advanced fulltext search capabilities to Redmine. PostgreSQL required.'
  author 'Jens Krämer/AlphaNodes'
  version '1.0.6'
  requires_redmine version_or_higher: '4.0'

  begin
    requires_redmine_plugin :additionals, version_or_higher: '2.0.22'
  rescue Redmine::PluginNotFound
    raise 'Please install additionals plugin (https://github.com/alphanodes/additionals)'
  end

  settings default: Additionals.load_settings('redmine_postgresql_search'), partial: 'settings/postgresql_search/postgresql_search'
end

begin
  if ActiveRecord::Base.connection.table_exists?(Setting.table_name)
    Rails.configuration.to_prepare do
      if Redmine::Database.postgresql?
        RedminePostgresqlSearch.setup
      else
        'You are not using PostgreSQL. The redmine_postgresql_search plugin will not do anything.'
      end
    end
  end
rescue ActiveRecord::NoDatabaseError
  Rails.logger.error 'database not created yet'
end
