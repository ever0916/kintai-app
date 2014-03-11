class RemoveTKintaiFromKintais < ActiveRecord::Migration
  def change
    remove_column :kintais, :t_kintai, :datetime
  end
end
