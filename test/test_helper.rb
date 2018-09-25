$VERBOSE = nil

require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

class RedminePostgresqlSearchTest < ActiveSupport::TestCase
  def with_postgresql_search_settings(settings, &_block)
    change_postgresql_search_settings(settings)
    yield
  ensure
    restore_postgresql_search_settings
  end

  def change_postgresql_search_settings(settings)
    @saved_settings = Setting.plugin_redmine_postgresql_search.dup
    new_settings = Setting.plugin_redmine_postgresql_search.dup
    settings.each do |key, value|
      new_settings[key] = value
    end
    Setting.plugin_redmine_postgresql_search = new_settings
  end

  def restore_postgresql_search_settings
    if @saved_settings
      Setting.plugin_redmine_postgresql_search = @saved_settings
    else
      Rails.logger.warn 'warning: restore_postgresql_search_settings could not restore settings'
    end
  end
end
