class Slot < ApplicationRecord
  belongs_to :costume
  belongs_to :equipped_memory, class_name: 'Memory', optional: true

  # メモリーが装備可能かどうかを判定
  def can_equip?(memory)
    # roleが一致している必要がある
    return false unless role == memory.role

    # slot_classが指定されている場合は、memory_classも一致している必要がある
    if slot_class.present?
      return false unless slot_class == memory.memory_class
    end

    # 選択しているキャラクター自身のメモリーは装着できない
    # キャラクター名の基本部分で比較（例：「緑谷出久（オリジナル）」→「緑谷出久」）
    costume_character_base_name = costume.character.name.split('（').first
    memory_character_base_name = memory.character.name.split('（').first
    return false if costume_character_base_name == memory_character_base_name

    # 同じコスチュームに同じメモリーを装着できない
    other_slots = costume.slots.where.not(id: id)
    return false if other_slots.exists?(equipped_memory_id: memory.id)

    true
  end

  # メモリーを装備
  def equip_memory(memory)
    raise "Cannot equip this memory to this slot" unless can_equip?(memory)

    update!(equipped_memory: memory)
  end

  # メモリーを解除
  def unequip_memory
    update!(equipped_memory: nil)
  end

  # スロットのレベルアップ
  def level_up
    return false if current_level >= max_level

    update!(current_level: current_level + 1)
  end

  # スロットのレベルダウン
  def level_down
    return false if current_level <= 1

    update!(current_level: current_level - 1)
  end
end
