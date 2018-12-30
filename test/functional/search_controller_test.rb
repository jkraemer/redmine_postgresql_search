require File.expand_path('../../test_helper', __FILE__)

class SearchControllerTest < Redmine::ControllerTest
  fixtures :projects, :projects_trackers,
           :enabled_modules, :roles, :users, :members, :member_roles,
           :issues, :trackers, :issue_statuses, :enumerations,
           :workflows,
           :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers,
           :repositories, :changesets,
           :wikis, :wiki_pages, :wiki_contents

  def setup
    User.current = nil
  end

  def test_search_for_projects
    get :index, params: { q: 'cook' }
    assert_response :success
    assert_select '#search-results dt.project a', text: /eCookbook/
  end

  def test_search_on_archived_project_should_return_403
    Project.find(3).archive
    get :index, params: { id: 3 }
    if Rails.version >= '5.2'
      assert_response 403
    else
      assert_response 404
    end
  end

  def test_search_on_invisible_project_by_user_should_be_denied
    @request.session[:user_id] = 7
    get :index, params: { id: 2 }
    assert_response 403
  end

  def test_search_on_invisible_project_by_anonymous_user_should_redirect
    get :index, params: { id: 2 }
    assert_response 302
  end

  def test_search_on_private_project_by_member_should_succeed
    @request.session[:user_id] = 2
    get :index, params: { id: 2 }
    assert_response :success
  end

  def test_search_all_projects
    with_settings default_language: 'en' do
      get :index, params: { q: 'recipe subproject commit', all_words: '' }
    end
    assert_response :success

    assert_select '#search-results'
    assert_select '#search-results-counts' do
      assert_select 'a', text: 'Changesets (5)'
    end
  end

  def test_search_issues
    get :index, params: { q: 'issue', issues: 1 }
    assert_response :success

    assert_select 'input[name=all_words]:not([checked])'
    assert_select 'input[name=titles_only]:not([checked])'

    assert_select '#search-results' do
      assert_select 'dt.issue a', text: /Bug #5/
      assert_select 'dt.issue-closed a', text: /Bug #8 \(Closed\)/
    end
  end

  def test_search_issues_should_search_notes
    Journal.create!(journalized: Issue.find(2), notes: 'Issue notes with searchkeyword')

    get :index, params: { q: 'searchkeyword', issues: 1 }
    assert_response :success
  end

  def test_search_issues_with_multiple_matches_in_journals_should_return_issue_once
    Journal.create!(journalized: Issue.find(2), notes: 'Issue notes with searchkeyword')
    Journal.create!(journalized: Issue.find(2), notes: 'Issue notes with searchkeyword')

    get :index, params: { q: 'searchkeyword', issues: 1 }
    assert_response :success
  end

  def test_search_issues_should_search_private_notes_with_permission_only
    Journal.create!(journalized: Issue.find(2), notes: 'Private notes with searchkeyword', private_notes: true)
    @request.session[:user_id] = 2

    Role.find(1).add_permission! :view_private_notes
    get :index, params: { q: 'searchkeyword', issues: 1 }
    assert_response :success
  end

  def test_search_all_projects_with_scope_param
    get :index, params: { q: 'issue', scope: 'all' }
    assert_response :success

    assert_select '#search-results dt'
  end

  def test_search_my_projects
    @request.session[:user_id] = 2
    get :index, params: { id: 1, q: 'recipe subproject', scope: 'my_projects', all_words: '' }
    assert_response :success

    assert_select '#search-results' do
      assert_select 'dt.issue', text: /Bug #1/
      assert_select 'dt', text: /Bug #5/, count: 0
    end
  end

  def test_search_my_projects_without_memberships
    # anonymous user has no memberships
    get :index, params: { id: 1, q: 'recipe subproject', scope: 'my_projects', all_words: '' }
    assert_response :success

    assert_select '#search-results' do
      assert_select 'dt', 0
    end
  end

  def test_search_project_and_subprojects
    get :index, params: { id: 1, q: 'recipe subproject', scope: 'subprojects', all_words: '' }
    assert_response :success

    assert_select '#search-results' do
      assert_select 'dt.issue', text: /Bug #1/
      assert_select 'dt.issue', text: /Bug #5/
    end
  end

  def test_search_without_searchable_custom_fields
    CustomField.update_all searchable: false

    get :index, params: { id: 1 }
    assert_response :success

    get :index, params: { id: 1, q: 'can' }
    assert_response :success
  end

  def test_search_with_searchable_custom_fields
    get :index, params: { id: 1, q: 'stringforcustomfield' }
    assert_response :success

    assert_select '#search-results' do
      assert_select 'dt.issue', text: /#7/
      assert_select 'dt', 1
    end
  end

  def test_search_without_attachments
    Issue.generate! subject: 'search_attachments'
    Attachment.generate! container: Issue.find(1), filename: 'search_attachments.patch'
    get :index, params: { id: 1, q: 'search_attachments', attachments: '0' }
    assert_response :success
    assert_select '#search-results'
  end

  def test_search_attachments_only
    Issue.generate! subject: 'search_attachments'
    Attachment.generate! container: Issue.find(1), filename: 'search_attachments.patch'

    get :index, params: { id: 1, q: 'search_attachments', attachments: 'only' }
    assert_response :success

    assert_select '#search-results' do
      assert_select 'dt.issue', text: / #1 /
      assert_select 'dt', 1
    end
  end

  def test_search_with_attachments
    Attachment.generate! container: Issue.find(1), filename: 'search_attachments.patch'

    get :index, params: { id: 1, q: 'search_attachments', attachments: '1' }
    assert_response :success
  end

  def test_search_open_issues
    Issue.generate! subject: 'search_open'
    Issue.generate! subject: 'search_open', status_id: 5

    get :index, params: { id: 1, q: 'search_open', open_issues: '1' }
    assert_response :success
    assert_select '#search-results'
  end

  def test_search_all_words
    # 'all words' is on by default
    get :index, params: { id: 1, q: 'recipe updating saving', all_words: '1' }
    assert_response :success

    assert_select 'input[name=all_words][checked=checked]'
    assert_select '#search-results' do
      assert_select 'dt.issue', text: / #3 /
      assert_select 'dt', 1
    end
  end

  def test_search_one_of_the_words
    get :index, params: { id: 1, q: 'recipe updating saving', all_words: '' }
    assert_response :success

    assert_select 'input[name=all_words]:not([checked])'
    assert_select '#search-results' do
      assert_select 'dt.issue', text: / #3 /
      assert_select 'dt', 4
    end
  end

  def test_search_titles_only_without_result
    get :index, params: { id: 1, q: 'recipe updating saving', titles_only: '1' }
    assert_response :success
    assert_select 'input[name=titles_only][checked=checked]'
  end

  def test_search_titles_only
    get :index, params: { id: 1, q: 'recipe', titles_only: '1' }
    assert_response :success

    assert_select 'input[name=titles_only][checked=checked]'
    assert_select '#search-results' do
      assert_select 'dt', 2
    end
  end

  def test_search_content
    Issue.where(id: 1).update_all("description = 'This is a searchkeywordinthecontent'")

    get :index, params: { id: 1, q: 'searchkeywordinthecontent', titles_only: '' }
    assert_response :success

    assert_select 'input[name=titles_only]:not([checked])'
    assert_select '#search-results'
  end

  def test_search_with_pagination
    issues = (0..24).map { Issue.generate! subject: 'search_with_limited_results' }.reverse

    get :index, params: { q: 'search_with_limited_results' }
    assert_response :success
    issues[0..9].each do |issue|
      assert_select '#search-results dt.issue', text: / ##{issue.id} /
    end

    get :index, params: { q: 'search_with_limited_results', page: 2 }
    assert_response :success
    issues[10..19].each do |issue|
      assert_select '#search-results dt.issue', text: / ##{issue.id} /
    end

    get :index, params: { q: 'search_with_limited_results', page: 3 }
    assert_response :success
    issues[20..24].each do |issue|
      assert_select '#search-results dt.issue', text: / ##{issue.id} /
    end

    get :index, params: { q: 'search_with_limited_results', page: 4 }
    assert_response :success
    assert_select '#search-results dt', 0
  end

  def test_search_with_invalid_project_id
    get :index, params: { id: 195, q: 'recipe' }
    assert_response 404
  end

  def test_quick_jump_to_issue
    # issue of a public project
    get :index, params: { q: '3' }
    assert_redirected_to '/issues/3'

    # issue of a private project
    get :index, params: { q: '4' }
    assert_response :success
  end

  def test_large_integer
    get :index, params: { q: '4615713488' }
    assert_response :success
  end

  def test_tokens_with_quotes
    get :index, params: { q: '"good bye" hello "bye bye"', all_words: '' }
    assert_response :success
  end

  def test_results_should_be_escaped_once
    assert Issue.find(1).update(subject: '<subject> escaped_once', description: '<description> escaped_once')
    get :index, params: { q: 'escaped_once' }
    assert_response :success
    assert_select '#search-results' do
      assert_select 'dt.issue a', text: /<subject>/
      assert_select 'dd', text: /<description>/
    end
  end

  def test_keywords_should_be_highlighted
    assert Issue.find(1).update(subject: 'subject highlighted', description: 'description highlighted')
    get :index, params: { q: 'highlighted' }
    assert_response :success
    assert_select '#search-results' do
      assert_select 'dt.issue a span.highlight', text: 'highlighted'
      assert_select 'dd span.highlight', text: 'highlighted'
    end
  end
end
