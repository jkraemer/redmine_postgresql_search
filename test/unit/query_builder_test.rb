require File.expand_path('../../test_helper', __FILE__)

class QueryBuilderTest < RedminePostgresqlSearchTest
  test 'should build all words query' do
    assert_query 'find & foo',
                 'find foo', all_words: true
  end

  test 'should build only titles query' do
    assert_query 'find:A & foo:A',
                 'find foo', all_words: true, titles_only: true
  end

  private

  def assert_query(sql_query, query, options = {})
    assert_equal sql_query, query_builder(query, options).send(:searchable_query)
  end

  def query_builder(query, options = {})
    RedminePostgresqlSearch::QueryBuilder.new query, options
  end
end
