class FulltextIndex < ActiveRecord::Base
  belongs_to :searchable, polymorphic: true, required: true

  # valid weight keys. the default weights assigned are {1, 0.4, 0.2, 0.1}
  WEIGHTS = %w(A B C D)
  SET_WEIGHT = "setweight(to_tsvector(:config, :text), :weight)"

  scope :search, ->(q){ where "plainto_tsquery(:config, :query) @@ tsv", config: FulltextIndex.lanuage_config, query: q}

  # TODO make this a setting
  CONFIG = "redmine_english"
  def self.lanuage_config
    CONFIG
  end

  def update_index!
    tsvector = searchable.index_data.map do |weight, value|
      weight = weight.to_s.upcase
      raise "illegal weight key #{weight}" unless WEIGHTS.include?(weight)
      if value.present?
        self.class.send(
          :sanitize_sql_array,
          [SET_WEIGHT, {config: self.class.lanuage_config,
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
