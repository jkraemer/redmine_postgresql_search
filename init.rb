Redmine::Plugin.register :redmine_postgresql_search do
  name 'Redmine PostgreSQL Search Plugin'
  url  'http://redmine-search.com/'
  description 'This plugin adds advanced fulltext search capabilities to Redmine. PostgreSQL required.'
  author 'Jens Krämer/AlphaNodes'
  version '1.0.3'

  begin
    requires_redmine_plugin :additionals, version_or_higher: '2.0.17'
  rescue Redmine::PluginNotFound
    raise 'Please install additionals plugin (https://github.com/alphanodes/additionals)'
  end

  settings default: {
    all_words_by_default: 1,
    age_weight_min: 0.1,
    age_weight_lifetime: 365
  }, partial: 'settings/postgresql_search/postgresql_search'
end

Rails.configuration.to_prepare do
  if Redmine::Database.postgresql?
    RedminePostgresqlSearch.setup
  else
    'You are not using PostgreSQL. The redmine_postgresql_search plugin will not do anything.'
  end
end
