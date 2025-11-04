class AddUsernameToEntries < ActiveRecord::Migration[6.1]
  def change
    add_column :entries, :username, :string
  end
end
