require File.expand_path('../../test_helper', __FILE__)

class FulltextIndexTest < RedminePostgresqlSearchTest
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
    @wiki = Wiki.find(1)
  end

  test 'wiki page should create index' do
    page = nil
    assert_difference 'FulltextIndex.count', 1 do
      assert_difference 'WikiPage.count', 1 do
        page = create_wiki_page title: 'Some Page', text: 'the page content'
      end
    end
    assert page.fulltext_index.present?
    assert r = FulltextIndex.search('some & page & content')
    assert_equal 1, r.size
    assert_equal page, r.first.searchable
  end

  test 'issue should create index' do
    issue = nil
    assert_difference 'FulltextIndex.count', 6 do
      assert_difference 'Issue.count', 1 do
        assert_difference 'CustomValue.count', 5 do
          issue = create_issue subject: 'find the issue',
                               description: 'issue description'
        end
      end
    end
    assert issue.fulltext_index.present?
    assert_equal issue, FulltextIndex.search('find & description').first.searchable
  end

  test 'issue journal should update index' do
    issue = create_issue subject: 'find the issue',
                         description: 'issue description'
    assert_difference 'FulltextIndex.count', 1 do
      assert_difference 'Journal.count', 1 do
        issue.init_journal(User.find(1), 'hello from your friendly journal')
        issue.save
      end
    end
    assert issue.fulltext_index.present?
    assert_equal issue, FulltextIndex.search('find').first.try(:searchable), 'should find by title'
    assert_equal issue, FulltextIndex.search('find & description').first.try(:searchable), 'should find by title and description'
    assert r = FulltextIndex.search('friendly & journal').first, 'should find by journal text'
    assert_equal issue, r.searchable.issue
    # TODO: how to accomplish this?
    # stock redmine has the same problem...
    # assert r = FulltextIndex.search('find journal').first, 'should find by title and journal text'
  end

  test 'should index attachments' do
    i = Issue.generate! subject: 'search attachments'
    a = Attachment.generate! container: i, filename: 'findme.pdf'
    assert r = FulltextIndex.search('findme')
    assert_equal 1, r.size
    assert_equal a, r.first.searchable
  end

  def create_wiki_page(attributes = {})
    text = attributes.delete(:text) || 'lorem ipsum'
    attributes[:wiki] ||= @wiki
    WikiPage.new(attributes).tap do |page|
      page.content = WikiContent.new(page: page, text: text)
      page.save
    end
  end

  def create_issue(attributes = {})
    Issue.create({ project_id: @project.id,
                   tracker_id: 1, author_id: 1,
                   status_id: 1, priority: IssuePriority.first,
                   subject: 'Issue 1' }.merge(attributes))
  end
end
