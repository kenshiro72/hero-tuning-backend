class Api::V1::CostumesController < ApplicationController
  # TODO: 認証実装時に認可チェックを追加
  # - 全てのアクションでユーザー所有のコスチュームかチェック
  # - IDOR脆弱性対策として、costume.character.user_id == current_user.id を確認

  # GET /api/v1/costumes
  def index
    # TODO: current_user.costumes に変更
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
    # TODO: 認可チェック - costume.character.user == current_user
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

  # POST /api/v1/costumes/:id/calculate_effects
  # ローカル状態のスロット構成で効果を計算（DB保存なし）
  def calculate_effects
    costume_id = validate_id_parameter(params[:id])
    costume = Costume.includes(:slots).find(costume_id)

    # リクエストボディからスロット構成を取得
    slots_config = params[:slots] || []

    # スロットごとのメモリーIDマップを作成
    memory_ids = slots_config.filter_map { |slot_data| slot_data[:equipped_memory_id] }.compact
    memories_by_id = Memory.where(id: memory_ids).includes(:character).index_by(&:id)

    # 各スロットに一時的にメモリーを設定（DB保存なし）
    costume.slots.each do |slot|
      slot_data = slots_config.find { |s| s[:id] == slot.id }
      next unless slot_data

      # current_levelを一時的に設定
      slot.current_level = slot_data[:current_level] if slot_data[:current_level]

      # equipped_memoryを一時的に設定
      if slot_data[:equipped_memory_id]
        slot.equipped_memory = memories_by_id[slot_data[:equipped_memory_id]]
      else
        slot.equipped_memory = nil
      end
    end

    # 効果を計算
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

    # トランザクション内で全ての更新を実行
    # 途中で失敗した場合は全てロールバック
    ActiveRecord::Base.transaction do
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
          # トランザクションをロールバックするため例外を発生
          raise ActiveRecord::RecordNotFound, "Invalid slot_id or memory_id"
        end

        unless slot.can_equip?(memory)
          # トランザクションをロールバックするため例外を発生
          raise ActiveRecord::RecordInvalid.new(slot), "Cannot equip memory #{memory_id} to slot #{slot_id}"
        end

        slot.update!(equipped_memory_id: memory_id)
      end
    end

    render json: {
      message: "構成を適用しました",
      costume_id: costume.id
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def configuration_params
    params.permit(configuration: {})
  end
end
