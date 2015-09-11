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
class SetupTsearch < ActiveRecord::Migration
  def up
    enable_extension 'unaccent'
    execute <<-SQL
        CREATE TEXT SEARCH CONFIGURATION redmine_english (COPY = 'english');
        ALTER TEXT SEARCH CONFIGURATION redmine_english ALTER MAPPING FOR hword, hword_part, word with unaccent, english_stem;
    SQL
  end

  def down
    execute "drop text search configuation redmine_english"
  end
end
