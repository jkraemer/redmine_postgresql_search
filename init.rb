Redmine::Plugin.register :redmine_postgresql_search do
  name 'Redmine PostgreSQL Search Plugin'
  url  'http://redmine-search.com/'

  description 'This plugin adds advanced fulltext search capabilities to Redmine. PostgreSQL required.'

  author 'Jens Krämer/AlphaNodes'

  version '1.0.2'

  settings default: {
    all_words_by_default: 1,
    update_time_factor: 0.1
  }, partial: 'settings/postgresql_search/postgresql_search'

  requires_redmine version_or_higher: '3.1.0'
end

Rails.configuration.to_prepare do
  if Redmine::Database.postgresql?
    RedminePostgresqlSearch.setup
  else
    'You are not using PostgreSQL. The redmine_postgresql_search plugin will not do anything.'
  end
end
