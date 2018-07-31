require File.expand_path('../../test_helper', __FILE__)
require 'ostruct'

class TokenizerTest < RedminePostgresqlSearchTest
  test 'should compile index data' do
    record = OpenStruct.new title: 'This is the title', description: 'description text', other_field: 'some_strange/filename.pdf'
    t = RedminePostgresqlSearch::Tokenizer.new(record,
                                               a: :title,
                                               b: %i[description other_field],
                                               c: -> { 'foo' },
                                               d: [-> { 'foo' }, :other_field])
    assert d = t.index_data
    assert_equal 'This is the title', d[:a]
    assert_equal 'description text some strange filename pdf', d[:b]
    assert_equal 'foo', d[:c]
    assert_equal 'foo some strange filename pdf', d[:d]
  end
end
