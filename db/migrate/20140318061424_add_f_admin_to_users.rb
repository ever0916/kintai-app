class AddFAdminToUsers < ActiveRecord::Migration
  def change
    add_column :users, :f_admin, :boolean, :default => "0"
  end
end
