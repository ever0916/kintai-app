class CreateKintais < ActiveRecord::Migration
  def change
    create_table :kintais do |t|
      t.integer :user_id
      t.datetime :t_kintai

      t.timestamps
    end
  end
end
