require 'csv'

class TuningSkillCalculator
  # チューニングスキルデータを読み込み
  def self.skill_data
    @skill_data ||= begin
      csv_path = Rails.root.join('db', 'チューニングスキルのレベル別効果.csv')
      data = {}

      CSV.foreach(csv_path, headers: true, encoding: 'UTF-8') do |row|
        skill_name = row['チューニングスキル名']
        effects_str = row['チューニングレベルごとの効果量']

        # "level1:1,level2:2,level3:3,level4:4" のような文字列をパース
        effects = {}
        effects_str.split(',').each do |pair|
          level, value = pair.split(':')
          level_num = level.gsub('level', '').to_i
          effects[level_num] = value.to_f
        end

        data[skill_name] = {
          description: row['効果'],
          effects: effects
        }
      end

      data
    end
  end

  # スペシャルチューニングスキルデータを読み込み
  def self.special_skill_data
    @special_skill_data ||= begin
      csv_path = Rails.root.join('db', 'スペシャルチューニングスキルのレベル別効果.csv')
      data = {}

      CSV.foreach(csv_path, headers: true, encoding: 'UTF-8') do |row|
        skill_name = row['スペシャルチューニングスキル名']
        effects_str = row['チューニングレベルごとの効果量']

        # "level1:1.1,level2:1.2,..." のような文字列をパース
        effects = {}
        effects_str.split(',').each do |pair|
          level, value = pair.split(':')
          level_num = level.gsub('level', '').to_i
          effects[level_num] = value.to_f
        end

        data[skill_name] = {
          description: row['効果'],
          effects: effects
        }
      end

      data
    end
  end

  # スロットに装備されたメモリーの効果を計算
  def self.calculate_slot_effect(slot)
    return {} unless slot.equipped_memory.present?

    memory = slot.equipped_memory
    level = slot.current_level

    # Normal Slotの場合はtuning_skill、Special Slotの場合はspecial_tuning_skillを使用
    skills_text = if slot.slot_type == 'Normal'
                    memory.tuning_skill
                  else
                    # Special slotはステータスに影響しないが、スキル名だけ返す
                    return { special_skill: memory.special_tuning_skill }
                  end

    return {} if skills_text.nil?

    # 複数のスキルがカンマ区切りで記載されている場合に対応
    # 例: "走り速度＋、格闘攻撃力＋"
    skills = skills_text.split(/、|,/).map(&:strip)

    effects = {}
    skills.each do |skill_name|
      if skill_data[skill_name]
        effect_value = skill_data[skill_name][:effects][level]
        if effect_value
          effects[skill_name] = {
            description: skill_data[skill_name][:description],
            value: effect_value
          }
        end
      end
    end

    effects
  end

  # 倍率系スキル（掛け算で合算）のリスト
  MULTIPLICATIVE_SKILLS = [
    '対HP攻撃力＋',
    '対GP攻撃力＋',
    '"個性"技α攻撃力＋',
    '"個性"技β攻撃力＋',
    '"個性"技γ攻撃力＋',
    '格闘攻撃力＋',
    'HP防御力＋',
    '対"個性"技α防御力＋',
    '対"個性"技β防御力＋',
    '対"個性"技γ防御力＋',
    '対格闘攻撃防御力＋',
    '走り速度＋',
    'ダッシュ速度＋',
    '壁移動速度＋',
    '瀕死移動速度＋',
    '"個性"技αリロード＋',
    '"個性"技βリロード＋',
    '"個性"技γリロード＋',
    '特殊アクションリロード＋',
    'PU/PCリロード＋'
  ]

  # フィクサーの倍率を取得
  # @param costume [Costume] コスチューム
  # @return [Hash] { slot_number => multiplier } の形式でフィクサーの倍率を返す
  def self.get_fixer_multipliers(costume)
    multipliers = {}

    # スペシャルスロットをチェック
    costume.slots.where(slot_type: 'Special').each do |slot|
      next unless slot.equipped_memory.present?

      # フィクサーが装備されているか確認
      special_skill = slot.equipped_memory.special_tuning_skill
      if special_skill == 'フィクサー'
        # フィクサーの倍率を取得（スペシャルスロットのmax_levelを使用）
        multiplier = special_skill_data['フィクサー'][:effects][slot.max_level]

        # スペシャルスロット1（slot_number=11）→ノーマルスロット1～5
        # スペシャルスロット2（slot_number=12）→ノーマルスロット6～10
        if slot.slot_number == 11
          (1..5).each { |n| multipliers[n] = multiplier }
        elsif slot.slot_number == 12
          (6..10).each { |n| multipliers[n] = multiplier }
        end
      end
    end

    multipliers
  end

  # コスチューム全体の効果を集計
  def self.calculate_costume_effects(costume)
    total_effects = {}
    special_skills = []

    # フィクサーの倍率を取得
    fixer_multipliers = get_fixer_multipliers(costume)

    costume.slots.includes(:equipped_memory).each do |slot|
      slot_effects = calculate_slot_effect(slot)

      # Special skillsは別で管理
      if slot_effects[:special_skill]
        special_skills << slot_effects[:special_skill]
        next
      end

      # ノーマルスロットの場合、フィクサーの倍率を適用
      if slot.slot_type == 'Normal' && fixer_multipliers[slot.slot_number]
        multiplier = fixer_multipliers[slot.slot_number]
        slot_effects.each do |skill_name, effect_data|
          if MULTIPLICATIVE_SKILLS.include?(skill_name)
            # 倍率系スキルの場合: 基準値からの差分に倍率を掛ける
            # 例: 1.02の場合、1.0 + (1.02 - 1.0) * 2.0 = 1.04
            effect_data[:value] = 1.0 + (effect_data[:value] - 1.0) * multiplier
          else
            # 加算系スキルの場合: 効果量に直接倍率を掛ける
            # 例: 3の場合、3 * 2.0 = 6
            effect_data[:value] *= multiplier
          end
        end
      end

      # 同じスキルの効果を合算
      slot_effects.each do |skill_name, effect_data|
        if total_effects[skill_name]
          # 倍率系スキルは掛け算、加算系スキルは足し算
          if MULTIPLICATIVE_SKILLS.include?(skill_name)
            # 倍率系: 0.99 * 0.99 = 0.9801
            total_effects[skill_name][:value] *= effect_data[:value]
          else
            # 加算系: 1 + 2 = 3
            total_effects[skill_name][:value] += effect_data[:value]
          end
        else
          total_effects[skill_name] = effect_data.dup
        end
      end
    end

    {
      tuning_effects: total_effects,
      special_skills: special_skills
    }
  end

  # 効果を％表記に変換
  def self.format_effect_percentage(skill_name, value)
    # 倍率系のスキルの場合（0.9～1.1の範囲）
    if value > 0.5 && value < 1.5
      # 1.01 -> 0.01 -> 1.00% のように変換
      # 0.99 -> -0.01 -> -1.00% のように変換
      percentage = ((value - 1.0) * 100).round(2)
      percentage >= 0 ? "+#{percentage}%" : "#{percentage}%"
    else
      # 加算系のスキルの場合（最大HP+など）
      "+#{value.to_i}"
    end
  end
end
