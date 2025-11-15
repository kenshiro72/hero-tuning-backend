class Api::V1::SlotsController < ApplicationController
  # POST /api/v1/slots/:id/equip
  def equip
    slot = Slot.find(params[:id])
    memory = Memory.find(params[:memory_id])

    unless slot.can_equip?(memory)
      # 詳細なエラーメッセージを生成
      error_message = []

      if slot.role != memory.role
        error_message << "Role不一致"
      end

      if slot.slot_class.present? && slot.slot_class != memory.memory_class
        error_message << "Class不一致"
      end

      costume_character_base = slot.costume.character.name.split('（').first
      memory_character_base = memory.character.name.split('（').first
      if costume_character_base == memory_character_base
        error_message << "自分自身のメモリーは装備できません"
      end

      other_slots = slot.costume.slots.where.not(id: slot.id)
      if other_slots.exists?(equipped_memory_id: memory.id)
        error_message << "同じメモリーが既に装備されています"
      end

      return render json: {
        error: error_message.join('、'),
        details: {
          slot_role: slot.role,
          slot_class: slot.slot_class,
          memory_role: memory.role,
          memory_class: memory.memory_class,
          costume_character: slot.costume.character.name,
          memory_character: memory.character.name
        }
      }, status: :unprocessable_entity
    end

    if slot.equip_memory(memory)
      render json: {
        message: "メモリーを装備しました",
        slot: slot.as_json(include: { equipped_memory: { include: :character } })
      }
    else
      render json: { error: "装備に失敗しました" }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/slots/:id/unequip
  def unequip
    slot = Slot.find(params[:id])

    if slot.unequip_memory
      render json: {
        message: "メモリーを解除しました",
        slot: slot
      }
    else
      render json: { error: "解除に失敗しました" }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/slots/:id/level_up
  def level_up
    slot = Slot.find(params[:id])

    if slot.level_up
      render json: {
        message: "レベルアップしました",
        slot: slot
      }
    else
      render json: { error: "これ以上レベルアップできません" }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/slots/:id/level_down
  def level_down
    slot = Slot.find(params[:id])

    if slot.level_down
      render json: {
        message: "レベルダウンしました",
        slot: slot
      }
    else
      render json: { error: "これ以上レベルダウンできません" }, status: :unprocessable_entity
    end
  end
end
