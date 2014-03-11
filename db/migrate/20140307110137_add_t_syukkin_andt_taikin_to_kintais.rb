class AddTSyukkinAndtTaikinToKintais < ActiveRecord::Migration
  def change
    add_column :kintais, :t_syukkin, :datetime
    add_column :kintais, :t_taikin, :datetime
  end
end
