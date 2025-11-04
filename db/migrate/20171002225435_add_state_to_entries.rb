class AddStateToEntries < ActiveRecord::Migration[6.1]
  def change
    add_column :entries, :state, :string
  end
end
