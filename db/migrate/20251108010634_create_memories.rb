class CreateMemories < ActiveRecord::Migration[8.0]
  def change
    create_table :memories do |t|
      t.references :character, null: false, foreign_key: true
      t.string :role
      t.string :memory_class
      t.text :effect

      t.timestamps
    end
  end
end
