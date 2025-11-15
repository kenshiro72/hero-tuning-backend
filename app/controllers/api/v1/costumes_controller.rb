class Api::V1::CostumesController < ApplicationController
  # GET /api/v1/costumes
  def index
    @costumes = Costume.all.includes(:character, :slots)
    render json: @costumes.as_json(
      include: {
        character: {},
        slots: {}
      }
    )
  end

  # GET /api/v1/costumes/:id
  def show
    costume = Costume.includes(slots: { equipped_memory: :character }).find(params[:id])

    render json: costume.as_json(
      include: {
        character: { only: [:id, :name, :role, :character_class, :hp] },
        slots: {
          include: {
            equipped_memory: {
              include: {
                character: { only: [:id, :name] }
              }
            }
          }
        }
      }
    )
  end

  # GET /api/v1/costumes/:id/effects
  def effects
    costume = Costume.includes(slots: :equipped_memory).find(params[:id])
    effects_data = TuningSkillCalculator.calculate_costume_effects(costume)

    # 効果を％表記に変換
    formatted_effects = {}
    effects_data[:tuning_effects].each do |skill_name, effect_data|
      formatted_value = TuningSkillCalculator.format_effect_percentage(skill_name, effect_data[:value])
      formatted_effects[skill_name] = {
        description: effect_data[:description],
        value: formatted_value
      }
    end

    render json: {
      costume: {
        id: costume.id,
        name: costume.name,
        rarity: costume.rarity,
        character: costume.character.name
      },
      tuning_effects: formatted_effects,
      special_skills: effects_data[:special_skills]
    }
  end

  # POST /api/v1/costumes/:id/unequip_all
  def unequip_all
    costume = Costume.find(params[:id])

    # コスチュームの全スロットからメモリーを解除
    costume.slots.update_all(equipped_memory_id: nil)

    render json: {
      message: "全てのメモリーを解除しました",
      costume_id: costume.id
    }
  end

  # POST /api/v1/costumes/:id/apply_configuration
  def apply_configuration
    costume = Costume.find(params[:id])
    configuration = params[:configuration] # { slot_id => memory_id }

    # 全スロットを解除
    costume.slots.update_all(equipped_memory_id: nil)

    # 新しい構成を適用
    configuration.each do |slot_id, memory_id|
      slot = costume.slots.find(slot_id)
      memory = Memory.find(memory_id)

      unless slot.can_equip?(memory)
        return render json: { error: "Cannot equip memory #{memory_id} to slot #{slot_id}" }, status: :unprocessable_entity
      end

      slot.update!(equipped_memory_id: memory_id)
    end

    render json: {
      message: "構成を適用しました",
      costume_id: costume.id
    }
  end
end
