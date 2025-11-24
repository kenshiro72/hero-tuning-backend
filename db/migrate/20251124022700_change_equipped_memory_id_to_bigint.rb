class ChangeEquippedMemoryIdToBigint < ActiveRecord::Migration[8.0]
  def up
    # 外部キー制約を一時的に削除
    remove_foreign_key :slots, :memories, column: :equipped_memory_id

    # integer から bigint に型変更
    change_column :slots, :equipped_memory_id, :bigint

    # 外部キー制約を再追加
    add_foreign_key :slots, :memories, column: :equipped_memory_id
  end

  def down
    # ロールバック時の処理
    remove_foreign_key :slots, :memories, column: :equipped_memory_id
    change_column :slots, :equipped_memory_id, :integer
    add_foreign_key :slots, :memories, column: :equipped_memory_id
  end
end
