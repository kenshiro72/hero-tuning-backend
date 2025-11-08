class CreateSlots < ActiveRecord::Migration[8.0]
  def change
    create_table :slots do |t|
      t.references :costume, null: false, foreign_key: true
      t.integer :slot_number
      t.string :slot_type
      t.string :role
      t.string :slot_class
      t.integer :max_level

      t.timestamps
    end
  end
end
