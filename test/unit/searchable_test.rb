require File.expand_path('../../test_helper', __FILE__)

class SearchableTest < RedminePostgresqlSearchTest
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :workflows,
           :custom_fields,
           :custom_fields_projects,
           :custom_fields_trackers,
           :wikis

  setup do
    Setting.default_language = 'en'
    @project = Project.find(1)
    @issue = Issue.generate! subject: 'findme test issue', description: 'test foobar'
  end

  test 'should not find issue twice when journal and issue match' do
    j = @issue.init_journal User.anonymous, 'this is a journal entry'
    j.save!

    ranks_and_ids = Issue.search_result_ranks_and_ids 'findme', @issue.author, [@project]
    assert_equal 1, ranks_and_ids.size
    assert_equal @issue.id, ranks_and_ids[0][1]
  end

end
