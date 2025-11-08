class CreateCostumes < ActiveRecord::Migration[8.0]
  def change
    create_table :costumes do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name
      t.string :rarity
      t.integer :star_level

      t.timestamps
    end
  end
end
