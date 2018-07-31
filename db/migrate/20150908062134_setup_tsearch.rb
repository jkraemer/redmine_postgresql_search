# PostgreSQL search config creation
#
# this sets up a config based on PostgreSQL's stock 'english' configuration and
# changes it so any accented characters in queries and documents are converted to
# their non-accented ASCII counterparts.
#
# You might want to change this if your Redmine installation has non-english
# content. See
# http://www.postgresql.org/docs/current/static/textsearch-configuration.html
# for more information.
class SetupTsearch < Rails.version < '5.2' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def up
    enable_extension 'unaccent'
    language = ENV['language'] || 'english'
    config_name = FulltextIndex::SEARCH_CONFIG
    execute <<-SQL
      CREATE TEXT SEARCH DICTIONARY #{config_name} ( TEMPLATE = snowball, Language = #{language}, StopWords = #{language} );
      CREATE TEXT SEARCH CONFIGURATION #{config_name} (COPY = '#{language}');
      ALTER TEXT SEARCH CONFIGURATION #{config_name} ALTER MAPPING FOR hword, hword_part, word with unaccent, #{config_name};
    SQL
  end

  def down
    config_name = FulltextIndex::SEARCH_CONFIG
    execute <<-SQL
      DROP TEXT SEARCH CONFIGURATION #{config_name};
      DROP TEXT SEARCH DICTIONARY #{config_name};
    SQL
  end
end
