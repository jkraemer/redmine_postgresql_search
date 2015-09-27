class FulltextIndex < ActiveRecord::Base
  belongs_to :searchable, polymorphic: true, required: true

  # valid weight keys. the default weights assigned are {1, 0.4, 0.2, 0.1}
  WEIGHTS = %w(A B C D)
  SET_WEIGHT = "setweight(to_tsvector(:config, :text), :weight)"

  # the postgresql indexing config to be used
  CONFIG = "redmine_search"

  scope :search, ->(q){ where "plainto_tsquery(:config, :query) @@ tsv", config: CONFIG, query: q}


  def update_index!
    tsvector = searchable.index_data.map do |weight, value|
      weight = weight.to_s.upcase
      raise "illegal weight key #{weight}" unless WEIGHTS.include?(weight)
      if value.present?
        self.class.send(
          :sanitize_sql_array,
          [SET_WEIGHT, {config: CONFIG,
                        text: value,
                        weight: weight}]
        )
      end
    end.compact.join(' || ')
    if tsvector.present?
      self.class.where(id: id).update_all "tsv = #{tsvector}"
    end
  end
end
