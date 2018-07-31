class AddUpdatedOnToFulltextIndices < Rails.version < '5.2' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def change
    add_column :fulltext_indices, :updated_on, :datetime
  end
end
