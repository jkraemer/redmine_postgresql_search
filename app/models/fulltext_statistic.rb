class FulltextStatistic
  def self.indices_count
    FulltextIndex.count
  end

  def self.words_count
    FulltextWord.count
  end

  def self.last_issue_id
    FulltextIndex.select(:searchable_id).order('id DESC').find_by(searchable_type: 'Issue').try(:searchable_id)
  end

  def self.last_issue_words
    words = FulltextIndex.select(:words).order('id DESC').find_by(searchable_type: 'Issue').try(:words)
    return '' if words.blank?

    words.join(', ')
  end

  def self.last_journal_words
    words = FulltextIndex.select(:words).order('id DESC').find_by(searchable_type: 'Journal').try(:words)
    return '' if words.blank?

    words.join(', ')
  end
end
