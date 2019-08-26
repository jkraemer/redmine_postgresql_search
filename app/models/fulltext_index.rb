class FulltextIndex < ActiveRecord::Base
  belongs_to :searchable, polymorphic: true, required: true

  # valid weight keys. the default weights assigned are {1, 0.4, 0.2, 0.1}
  WEIGHTS = %w[A B C D].freeze

  # the postgresql indexing config to be used
  SEARCH_CONFIG = 'redmine_search'.freeze
  WORD_CONFIG = 'redmine_search_words'.freeze

  scope :search, ->(q) { where 'to_tsquery(:config, :query) @@ tsv', config: SEARCH_CONFIG, query: q }

  def update_index!
    values = []
    weights = []
    unless destroyed?
      searchable.index_data.each do |weight, value|
        weight = weight.to_s.upcase
        raise "illegal weight key #{weight}" unless WEIGHTS.include?(weight)
        next if value.blank?
        next if RedminePostgresqlSearch.settings[:disallow_multibyte_words] && multibyte?(value)

        values << self.class.connection.quote(value)
        weights << self.class.connection.quote(weight)
      end
    end

    values_sql = "Array[#{values.join(', ')}]::text[]"
    weights_sql = "Array[#{weights.join(', ')}]::char[]"

    self.class.connection.execute("SELECT update_search_data('#{SEARCH_CONFIG}', '#{WORD_CONFIG}', #{id}, #{values_sql}, #{weights_sql})")
  end

  private

  def multibyte?(value)
    # umlaute not included
    # value.length < value.bytesize
    for pos in 0...value.length
      return true if value[pos].ord > 255
    end

    false
  end
end
