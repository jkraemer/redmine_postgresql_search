class CreateFulltextIndices < ActiveRecord::Migration
  def up
    create_table :fulltext_indices do |t|
      t.references :searchable, polymorphic: true, index: true, unique: true
      t.references :project, index: true
    end
    execute %{ALTER TABLE fulltext_indices ADD COLUMN tsv TSVECTOR}
    execute %{CREATE INDEX fulltext_indices_tsv_idx ON fulltext_indices USING GIN(tsv)}
  end

  def down
    drop_table :fulltext_indices
  end
end
