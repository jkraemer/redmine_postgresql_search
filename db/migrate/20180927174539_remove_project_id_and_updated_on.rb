class RemoveProjectIdAndUpdatedOn < Rails.version < '5.2' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def change
    remove_column :fulltext_indices, :updated_on, :datetime
    remove_reference :fulltext_indices, :project, index: true
  end
end
