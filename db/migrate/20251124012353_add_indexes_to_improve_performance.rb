class AddIndexesToImprovePerformance < ActiveRecord::Migration[8.0]
  def change
    # キャラクター名でのバリアント検索を高速化
    # 使用箇所: CharactersController#show (バリアント検索)
    add_index :characters, :name

    # コスチュームごとのスロット番号の一意性を保証
    # データ整合性: 同じコスチュームに同じスロット番号が重複するのを防ぐ
    # 使用箇所: CostumeOptimizer (スロット検索の高速化)
    add_index :slots, [:costume_id, :slot_number], unique: true
  end
end
