class AddEquipmentToSlots < ActiveRecord::Migration[8.0]
  def change
    add_column :slots, :equipped_memory_id, :integer
    add_column :slots, :current_level, :integer, default: 1, null: false
    add_foreign_key :slots, :memories, column: :equipped_memory_id
  end
end
