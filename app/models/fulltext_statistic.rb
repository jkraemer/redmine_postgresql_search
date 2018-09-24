class FulltextStatistic
  def self.indices_count
    FulltextIndex.count
  end

  def self.words_count
    FulltextWord.count
  end
end
