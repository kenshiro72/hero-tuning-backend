class CreateCharacters < ActiveRecord::Migration[8.0]
  def change
    create_table :characters do |t|
      t.string :name
      t.string :role
      t.string :character_class
      t.integer :hp
      t.integer :alpha_damage
      t.integer :beta_damage
      t.integer :gamma_damage

      t.timestamps
    end
  end
end
