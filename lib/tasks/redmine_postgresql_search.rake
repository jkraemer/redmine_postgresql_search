namespace :redmine_postgresql_search do
  desc 'reindexes all searchable models'
  task rebuild_index: :environment do
    RedminePostgresqlSearch.rebuild_indices
  end
end
