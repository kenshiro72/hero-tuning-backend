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
    costume_id = validate_id_parameter(params[:id])
    costume = Costume.includes(slots: { equipped_memory: :character }).find(costume_id)

    render json: costume.as_json(
      include: {
        character: { only: [ :id, :name, :role, :character_class, :hp ] },
        slots: {
          include: {
            equipped_memory: {
              include: {
                character: { only: [ :id, :name ] }
              }
            }
          }
        }
      }
    )
  end

  # GET /api/v1/costumes/:id/effects
  def effects
    costume_id = validate_id_parameter(params[:id])
    costume = Costume.includes(slots: :equipped_memory).find(costume_id)
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
    costume_id = validate_id_parameter(params[:id])
    # N+1クエリ対策: slotsをeager load
    costume = Costume.includes(:slots).find(costume_id)

    # コスチュームの全スロットからメモリーを解除
    costume.slots.update_all(equipped_memory_id: nil)

    render json: {
      message: "全てのメモリーを解除しました",
      costume_id: costume.id
    }
  end

  # POST /api/v1/costumes/:id/apply_configuration
  def apply_configuration
    costume_id = validate_id_parameter(params[:id])
    # N+1クエリ対策: slotsをeager load
    costume = Costume.includes(:slots).find(costume_id)

    # Strong Parametersを使用してパラメータをホワイトリスト化
    config_params = configuration_params
    configuration = config_params[:configuration]

    # configurationがハッシュであることを検証
    unless configuration.is_a?(Hash) || configuration.is_a?(ActionController::Parameters)
      return render json: { error: "configuration must be a hash" }, status: :bad_request
    end

    # 全スロットを解除
    costume.slots.update_all(equipped_memory_id: nil)

    # N+1クエリ対策: 必要なmemoriesを一度に取得
    memory_ids = configuration.values.map { |id| validate_id_parameter(id) }
    memories = Memory.where(id: memory_ids).index_by(&:id)

    # slotsをハッシュ化してアクセスを高速化
    slots_by_id = costume.slots.index_by(&:id)

    # 新しい構成を適用
    configuration.each do |slot_id_param, memory_id_param|
      # IDパラメータをバリデーション
      slot_id = validate_id_parameter(slot_id_param)
      memory_id = validate_id_parameter(memory_id_param)

      slot = slots_by_id[slot_id]
      memory = memories[memory_id]

      unless slot && memory
        return render json: { error: "Invalid slot_id or memory_id" }, status: :bad_request
      end

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

  private

  def configuration_params
    params.permit(configuration: {})
  end
end
