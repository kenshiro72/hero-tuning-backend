class Api::V1::CharactersController < ApplicationController
  def index
    @characters = Character.all
    render json: @characters
  end

  def show
    character_id = validate_id_parameter(params[:id])
    @character = Character.includes(costumes: { slots: { equipped_memory: :character } }, memory: {}).find(character_id)
    render json: @character.as_json(
      include: {
        costumes: {
          include: {
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
        },
        memory: {}
      }
    )
  end

  # GET /api/v1/characters/:id/with_variants
  # パフォーマンス最適化: 同じベース名のキャラクターを一度に取得
  def with_variants
    character_id = validate_id_parameter(params[:id])
    character = Character.find(character_id)

    # ベース名を取得
    base_name = character.name.split("（").first

    # 同じベース名を持つすべてのキャラクターを取得（N+1クエリ対策）
    # ベース名と完全一致、またはベース名の後に「（」が続くもののみ取得
    # これにより「緑谷出久」と「緑谷出久 OFA」を区別できる
    # LIKE特殊文字（%、_）をエスケープしてSQL injectionを防止
    escaped_base_name = Character.sanitize_sql_like(base_name)
    variants = Character.where("name = ? OR name LIKE ?", escaped_base_name, "#{escaped_base_name}（%")
                       .includes(costumes: { slots: { equipped_memory: :character } }, memory: {})

    # すべてのバリアントのコスチュームとメモリーを統合
    all_costumes = []
    all_memories = []

    variants.each do |variant|
      all_costumes.concat(variant.costumes) if variant.costumes.present?

      if variant.memory.present?
        if variant.memory.is_a?(Array)
          all_memories.concat(variant.memory)
        else
          all_memories << variant.memory
        end
      end
    end

    # コスチュームをシリーズ順にソート
    all_costumes.sort_by! { |costume| [costume.series_order, costume.id] }

    # 統合されたレスポンスを返す
    render json: {
      id: character.id,
      name: base_name,
      role: character.role,
      character_class: character.character_class,
      hp: character.hp,
      costumes: all_costumes.as_json(
        include: {
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
      ),
      memory: all_memories.as_json
    }
  end

  # POST /api/v1/characters/:id/optimize
  def optimize
    character_id = validate_id_parameter(params[:id])
    character = Character.includes(costumes: :slots).find(character_id)

    # Strong Parametersを使用してパラメータをホワイトリスト化
    optimization_params = optimize_params
    custom_skills = optimization_params[:custom_skills]
    special_slot_1_skill = optimization_params[:special_slot_1_skill]
    special_slot_2_skill = optimization_params[:special_slot_2_skill]
    special_slot_either_skill = optimization_params[:special_slot_either_skill]

    # バリデーション: custom_skillsの存在と空配列チェック
    unless custom_skills && custom_skills.any?
      return render json: { error: "custom_skills must be provided and not empty" }, status: :bad_request
    end

    # バリデーション: custom_skillsの各要素が文字列であることを確認
    unless custom_skills.all? { |skill| skill.is_a?(String) && skill.present? }
      return render json: { error: "All custom_skills must be non-empty strings" }, status: :bad_request
    end

    # バリデーション: スキル名の妥当性チェック
    valid_skills = TuningSkillCalculator.skill_data.keys
    invalid_skills = custom_skills.reject { |skill| valid_skills.include?(skill) }
    if invalid_skills.any?
      return render json: {
        error: "Invalid skill names",
        invalid_skills: invalid_skills,
        valid_skills: valid_skills
      }, status: :bad_request
    end

    # バリデーション: スペシャルスキル名の妥当性チェック（指定されている場合）
    # データベースに実際に存在するメモリーのスペシャルスキルを有効とする
    valid_special_skills = Memory.distinct.pluck(:special_tuning_skill).compact
    [special_slot_1_skill, special_slot_2_skill, special_slot_either_skill].compact.each do |skill|
      unless valid_special_skills.include?(skill)
        return render json: {
          error: "Invalid special skill name",
          invalid_skill: skill,
          valid_special_skills: valid_special_skills
        }, status: :bad_request
      end
    end

    # モードを判定
    filter_mode = determine_filter_mode(special_slot_1_skill, special_slot_2_skill, special_slot_either_skill)

    # eitherモードの場合、special_slot_1_skillに値を設定
    if filter_mode == "either"
      special_slot_1_skill = special_slot_either_skill
      special_slot_2_skill = nil
    end

    results = CostumeOptimizer.optimize(
      character,
      custom_skills: custom_skills,
      special_slot_1_skill: special_slot_1_skill,
      special_slot_2_skill: special_slot_2_skill,
      special_filter_mode: filter_mode
    )

    render json: {
      custom_skills: custom_skills,
      special_slot_1_skill: special_slot_1_skill,
      special_slot_2_skill: special_slot_2_skill,
      special_filter_mode: filter_mode,
      results: results
    }
  end

  private

  def optimize_params
    params.permit(
      :special_slot_1_skill,
      :special_slot_2_skill,
      :special_slot_either_skill,
      custom_skills: []
    )
  end

  def determine_filter_mode(slot_1, slot_2, either)
    if either.present?
      "either"
    elsif slot_1.present? && slot_2.present?
      "both"
    elsif slot_1.present?
      "special_1"
    elsif slot_2.present?
      "special_2"
    else
      "none"
    end
  end
end
