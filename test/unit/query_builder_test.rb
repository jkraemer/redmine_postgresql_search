require File.expand_path('../../test_helper', __FILE__)

class QueryBuilderTest < RedminePostgresqlSearchTest
  def setup
    RedminePostgresqlSearch.rebuild_indices
  end

  test 'should build all words query' do
    assert_query 'find&foo',
                 %w[find foo], all_words: true
  end

  test 'should build only titles query' do
    assert_query 'find:A&foo:A',
                 %w[find foo], all_words: true, titles_only: true
  end

  test 'ts_rank should respect settings' do
    with_postgresql_search_settings(age_weight_min: 0.23, age_weight_lifetime: 234) do
      ts_rank = query_builder([], all_words: true).search_sql([])
      assert_match '234', ts_rank
      assert_match '0.23', ts_rank
    end
  end

  private

  def assert_query(sql_query, query, options = {})
    assert_equal sql_query, query_builder(query, options).send(:search_query)
  end

  def query_builder(query, options = {})
    RedminePostgresqlSearch::QueryBuilder.new query, options
  end
end
