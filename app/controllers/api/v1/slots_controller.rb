class Api::V1::SlotsController < ApplicationController
  # POST /api/v1/slots/:id/equip
  def equip
    slot_id = validate_id_parameter(params[:id])
    # N+1クエリ対策: costume.characterとcostume.slotsをeager load
    slot = Slot.includes(costume: [:character, :slots]).find(slot_id)

    # Strong Parametersを使用してパラメータをホワイトリスト化
    equip_params_data = equip_params
    memory_id_param = equip_params_data[:memory_id]

    # memory_idをバリデーション
    return render json: { error: "memory_id is required" }, status: :bad_request unless memory_id_param.present?

    memory_id = validate_id_parameter(memory_id_param)
    # N+1クエリ対策: memory.characterをeager load
    memory = Memory.includes(:character).find(memory_id)

    unless slot.can_equip?(memory)
      # 詳細なエラーメッセージを生成
      error_message = []

      if slot.role != memory.role
        error_message << "Role不一致"
      end

      if slot.slot_class.present? && slot.slot_class != memory.memory_class
        error_message << "Class不一致"
      end

      costume_character_base = slot.costume.character.name.split("（").first
      memory_character_base = memory.character.name.split("（").first
      if costume_character_base == memory_character_base
        error_message << "自分自身のメモリーは装備できません"
      end

      other_slots = slot.costume.slots.where.not(id: slot.id)
      if other_slots.exists?(equipped_memory_id: memory.id)
        error_message << "同じメモリーが既に装備されています"
      end

      return render json: {
        error: error_message.join("、"),
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
    slot_id = validate_id_parameter(params[:id])
    slot = Slot.find(slot_id)

    if slot.unequip_memory
      render json: {
        message: "メモリーを解除しました",
        slot: slot
      }
    else
      render json: { error: "解除に失敗しました" }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/slots/:id/set_level
  # 一度に特定レベルに設定（パフォーマンス最適化）
  def set_level
    slot_id = validate_id_parameter(params[:id])
    slot = Slot.find(slot_id)

    # levelパラメータの存在確認
    unless params[:level].present?
      return render json: { error: "level parameter is required" }, status: :bad_request
    end

    # levelパラメータの型検証（正の整数であることを確認）
    begin
      target_level = validate_id_parameter(params[:level])
    rescue ArgumentError => e
      return render json: {
        error: "Invalid level format: must be a positive integer",
        details: e.message
      }, status: :bad_request
    end

    # レベルの範囲バリデーション
    unless target_level.between?(1, slot.max_level)
      return render json: {
        error: "Level out of range",
        current_level: slot.current_level,
        max_level: slot.max_level,
        requested_level: target_level
      }, status: :bad_request
    end

    # レベルを直接設定
    slot.update!(current_level: target_level)

    render json: {
      message: "レベルを#{target_level}に設定しました",
      slot: slot
    }
  end

  private

  def equip_params
    params.permit(:memory_id)
  end
end
