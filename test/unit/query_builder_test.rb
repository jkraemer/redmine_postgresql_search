require File.expand_path('../../test_helper', __FILE__)

class QueryBuilderTest < RedminePostgresqlSearchTest

  test 'should build title only prefix query' do
    assert_query 'find:*A | foo:A',
      'find* foo', titles_only: true
  end

  test 'should build global prefix query' do
    assert_query '(find:*A | find:*B | find:*C | find:*D) | foo',
      'find* foo'
  end

  test 'should build all words query' do
    assert_query 'find & foo',
      'find foo', all_words: true
  end

  test 'should build title only all words prefix query' do
    assert_query 'find:*A & foo:A',
      'find* foo', all_words: true, titles_only: true
  end

  test 'should build all words prefix query' do
    assert_query '(find:*A | find:*B | find:*C | find:*D) & foo',
      'find* foo', all_words: true
  end

  private

  def assert_query(sql_query, query, options = {})
    assert_equal sql_query, query_builder(query, options).send(:searchable_query)
  end

  def query_builder(query, options = {})
    RedminePostgresqlSearch::QueryBuilder.new query, options
  end

end

