class AddIndexToSlotsEquippedMemoryId < ActiveRecord::Migration[8.0]
  def change
    add_index :slots, :equipped_memory_id
  end
end
