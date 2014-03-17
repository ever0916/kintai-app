class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name,:null => false,:limit => 100, :default => ""
      t.boolean :f_state,:default => "0" # 1で勤務中。0で勤務外

      t.timestamps
    end
  end
end
