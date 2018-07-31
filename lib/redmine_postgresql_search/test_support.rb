# Fixture loading does not generate an index
#
# This brute force index rebuilding before each test slows down Redmine's test
# suite considerably, but at leasts tests pass (which they dont without index).
#
# For fast tests, you can always temporarily move the plugin out of plugins/...
class ActiveSupport::TestCase
  setup do
    RedminePostgresqlSearch.rebuild_indices
  end
end
