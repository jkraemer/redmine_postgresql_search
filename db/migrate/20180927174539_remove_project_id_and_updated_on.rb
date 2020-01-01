class RemoveProjectIdAndUpdatedOn < ActiveRecord::Migration[4.2]
  def change
    remove_column :fulltext_indices, :updated_on, :datetime
    remove_reference :fulltext_indices, :project, index: true
  end
end
