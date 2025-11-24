class CostumeOptimizer
  def self.optimize(character, custom_skills:, special_slot_1_skill: nil, special_slot_2_skill: nil, special_filter_mode: "none")
    # カスタムスキルは必須
    raise "custom_skills must be provided" unless custom_skills && custom_skills.any?

    target_skills = custom_skills
    results = []

    # スペシャルスキルでコスチュームをフィルタ
    costumes = if special_filter_mode != "none"
                 filter_costumes_by_special_skills(character.costumes, special_slot_1_skill, special_slot_2_skill, special_filter_mode)
    else
                 character.costumes
    end

    # 各コスチュームに対して最適化
    costumes.each do |costume|
      optimized = optimize_costume(costume, target_skills, special_slot_1_skill, special_slot_2_skill, special_filter_mode)
      results << optimized if optimized
    end

    # スコアでソートして上位5件
    results.sort_by { |r| -r[:score] }.first(5)
  end

  def self.optimize_costume(costume, target_skills, special_slot_1_skill = nil, special_slot_2_skill = nil, special_filter_mode = "none")
    # 全メモリーを取得（N+1クエリ防止のためcharacterを事前ロード）
    all_memories = Memory.includes(:character).to_a

    # 最適なメモリー構成を見つける（貪欲法）
    best_configuration = find_best_configuration(costume, all_memories, target_skills, special_slot_1_skill, special_slot_2_skill, special_filter_mode)

    return nil unless best_configuration

    # スコアを計算
    score = calculate_score(best_configuration[:effects], target_skills)

    {
      costume_id: costume.id,
      costume_name: costume.name,
      rarity: costume.rarity,
      star_level: costume.star_level,
      character_name: costume.character.name,
      score: score,
      configuration: best_configuration[:slots],
      effects: best_configuration[:effects]
    }
  end

  def self.find_best_configuration(costume, all_memories, target_skills, special_slot_1_skill = nil, special_slot_2_skill = nil, special_filter_mode = "none")
    # 各スロットに最適なメモリーを割り当て
    slot_assignments = {}

    # ★★★ まずスペシャルスロットの処理を先に行う ★★★
    special_slots = costume.slots.where(slot_type: "Special").order(:slot_number)
    slot_1 = special_slots.find_by(slot_number: 11)
    slot_2 = special_slots.find_by(slot_number: 12)

    # eitherモードの場合：Slot 1または2のどちらかに必ず指定されたスキルを装備（最優先）
    if special_filter_mode == "either" && special_slot_1_skill.present?
      specified_memory = all_memories.find { |m| m.special_tuning_skill == special_slot_1_skill }

      if specified_memory
        # まずSlot 1を試す
        if slot_1 && can_equip_memory?(slot_1, specified_memory, costume, slot_assignments)
          slot_assignments[slot_1.id] = specified_memory.id
        # Slot 1にできない場合、Slot 2を試す
        elsif slot_2 && can_equip_memory?(slot_2, specified_memory, costume, slot_assignments)
          slot_assignments[slot_2.id] = specified_memory.id
        end
      end
    else
      # eitherモード以外：通常の処理
      # スペシャル1のスキルが指定されている場合（最優先で装備）
      if special_slot_1_skill.present? && slot_1
        specified_memory = all_memories.find { |m| m.special_tuning_skill == special_slot_1_skill }
        if specified_memory && can_equip_memory?(slot_1, specified_memory, costume, slot_assignments)
          slot_assignments[slot_1.id] = specified_memory.id
        end
      end

      # スペシャル2のスキルが指定されている場合（最優先で装備）
      if special_slot_2_skill.present? && slot_2
        specified_memory = all_memories.find { |m| m.special_tuning_skill == special_slot_2_skill }
        if specified_memory && can_equip_memory?(slot_2, specified_memory, costume, slot_assignments)
          slot_assignments[slot_2.id] = specified_memory.id
        end
      end
    end

    # 指定がないスペシャルスロットに対してフィクサーを試す
    # eitherモード：1つのスロットに指定スキルが装備され、もう1つはフィクサーを試す
    # 通常モード：指定がないスロットにフィクサーを試す
    if special_filter_mode == "either" || special_slot_1_skill.blank? || special_slot_2_skill.blank?
      fixer_memory = all_memories.find { |m| m.special_tuning_skill == "フィクサー" }

      if fixer_memory
        special_slots.each do |slot|
          next if slot_assignments[slot.id].present?

          if can_equip_memory?(slot, fixer_memory, costume, slot_assignments)
            # フィクサーを仮装備してスコアを計算
            temp_assignments = slot_assignments.dup
            temp_assignments[slot.id] = fixer_memory.id

            # 他の互換性のあるメモリーと比較
            compatible_memories = all_memories.select { |m| can_equip_memory?(slot, m, costume, slot_assignments) }

            # フィクサーを装備（後でノーマルスロット最適化時にスコアで判断される）
            slot_assignments[slot.id] = fixer_memory.id
          end
        end
      end
    end

    # まだ装備されていないスペシャルスロットに最初の互換性のあるメモリーを割り当て
    special_slots.each do |slot|
      next if slot_assignments[slot.id].present?

      compatible_memories = all_memories.select do |memory|
        can_equip_memory?(slot, memory, costume, slot_assignments)
      end

      # 最初の互換性のあるメモリーを割り当て
      if compatible_memories.any?
        slot_assignments[slot.id] = compatible_memories.first.id
      end
    end

    # ★★★ スペシャルスロット処理完了後、ノーマルスロットを最適化 ★★★
    normal_slots = costume.slots.where(slot_type: "Normal").order(:slot_number)

    # まず全てのスロットに最初の互換性のあるメモリーを割り当て
    normal_slots.each do |slot|
      compatible_memories = all_memories.select do |memory|
        can_equip_memory?(slot, memory, costume, slot_assignments)
      end

      # 最初の互換性のあるメモリーを割り当て
      if compatible_memories.any?
        slot_assignments[slot.id] = compatible_memories.first.id
      end
    end

    # 次に、対象スキルに関連するスロットを最適化
    normal_slots.each do |slot|
      # このスロットに装備可能なメモリーを取得
      compatible_memories = all_memories.select do |memory|
        can_equip_memory?(slot, memory, costume, slot_assignments)
      end

      # 現在のメモリーも候補に含める
      current_memory_id = slot_assignments[slot.id]
      if current_memory_id
        current_memory = all_memories.find { |m| m.id == current_memory_id }
        compatible_memories << current_memory unless compatible_memories.include?(current_memory)
      end

      # 各メモリーを試してスコアを計算
      # メモリ最適化: ハッシュコピーの代わりに値を一時的に変更
      best_memory = nil
      best_score = 0
      original_memory_id = slot_assignments[slot.id]

      compatible_memories.each do |memory|
        # 一時的に割り当てを変更
        slot_assignments[slot.id] = memory.id

        # スコアを計算
        temp_effects = calculate_effects_for_assignments(costume, slot_assignments, all_memories)
        temp_score = calculate_score(temp_effects, target_skills)

        if temp_score > best_score
          best_score = temp_score
          best_memory = memory
        end
      end

      # 最適なメモリーを設定（見つからなければ元の値を維持）
      slot_assignments[slot.id] = best_memory ? best_memory.id : original_memory_id
    end

    # 最終的な効果を計算
    final_effects = calculate_effects_for_assignments(costume, slot_assignments, all_memories)

    {
      slots: slot_assignments.map do |slot_id, memory_id|
        slot = costume.slots.find(slot_id)
        memory = all_memories.find { |m| m.id == memory_id }

        # memoryがnilの場合はスキップ
        next unless memory

        {
          slot_id: slot_id,
          slot_number: slot.slot_number,
          slot_type: slot.slot_type,
          memory_id: memory_id,
          memory_name: memory.character.name,
          skill: slot.slot_type == "Normal" ? memory.tuning_skill : memory.special_tuning_skill,
          role: memory.role
        }
      end.compact,
      effects: final_effects
    }
  end

  def self.filter_costumes_by_special_skills(costumes, special_slot_1_skill, special_slot_2_skill, filter_mode)
    case filter_mode
    when "special_1"
      # スペシャル1のみ
      return [] unless special_slot_1_skill.present?
      memory_1 = Memory.find_by(special_tuning_skill: special_slot_1_skill)
      return [] unless memory_1

      costumes.select do |costume|
        slot_1 = costume.slots.find_by(slot_type: "Special", slot_number: 11)
        slot_1 && can_slot_equip_memory?(slot_1, memory_1)
      end

    when "special_2"
      # スペシャル2のみ
      return [] unless special_slot_2_skill.present?
      memory_2 = Memory.find_by(special_tuning_skill: special_slot_2_skill)
      return [] unless memory_2

      costumes.select do |costume|
        slot_2 = costume.slots.find_by(slot_type: "Special", slot_number: 12)
        slot_2 && can_slot_equip_memory?(slot_2, memory_2)
      end

    when "both"
      # 両方
      return [] unless special_slot_1_skill.present? && special_slot_2_skill.present?
      memory_1 = Memory.find_by(special_tuning_skill: special_slot_1_skill)
      memory_2 = Memory.find_by(special_tuning_skill: special_slot_2_skill)
      return [] unless memory_1 && memory_2

      costumes.select do |costume|
        slot_1 = costume.slots.find_by(slot_type: "Special", slot_number: 11)
        slot_2 = costume.slots.find_by(slot_type: "Special", slot_number: 12)
        slot_1 && slot_2 && can_slot_equip_memory?(slot_1, memory_1) && can_slot_equip_memory?(slot_2, memory_2)
      end

    when "either"
      # どちらか（スペシャル1or2用）
      return [] unless special_slot_1_skill.present?
      memory = Memory.find_by(special_tuning_skill: special_slot_1_skill)
      return [] unless memory

      costumes.select do |costume|
        slot_1 = costume.slots.find_by(slot_type: "Special", slot_number: 11)
        slot_2 = costume.slots.find_by(slot_type: "Special", slot_number: 12)
        (slot_1 && can_slot_equip_memory?(slot_1, memory)) || (slot_2 && can_slot_equip_memory?(slot_2, memory))
      end

    else
      costumes
    end
  end

  def self.can_slot_equip_memory?(slot, memory)
    # RoleとClassのチェック
    return false unless slot.role == memory.role
    return false if slot.slot_class.present? && slot.slot_class != memory.memory_class
    true
  end

  def self.can_equip_memory?(slot, memory, costume, current_assignments)
    # Roleチェック
    return false unless slot.role == memory.role

    # Classチェック
    if slot.slot_class.present?
      return false unless slot.slot_class == memory.memory_class
    end

    # 自分自身のメモリーチェック
    costume_character_base = costume.character.name.split("（").first
    memory_character_base = memory.character.name.split("（").first
    return false if costume_character_base == memory_character_base

    # 同じメモリーが既に使用されていないかチェック
    return false if current_assignments.values.include?(memory.id)

    true
  end

  def self.calculate_effects_for_assignments(costume, assignments, all_memories)
    total_effects = {}
    fixer_multipliers = {}

    # 最適化: 単一パスで全スロットを処理
    # 1. まずSpecialスロットを処理してフィクサー倍率を収集
    # 2. 次にNormalスロットの効果を計算
    special_slots = []
    normal_slots = []

    costume.slots.each do |slot|
      if slot.slot_type == "Special"
        special_slots << slot
      else
        normal_slots << slot
      end
    end

    # フィクサーの倍率を計算（Specialスロットのみ）
    special_slots.each do |slot|
      memory_id = assignments[slot.id]
      next unless memory_id

      memory = all_memories.find { |m| m.id == memory_id }
      next unless memory

      if memory.special_tuning_skill == "フィクサー"
        # CSVデータの存在チェック
        fixer_data = TuningSkillCalculator.special_skill_data["フィクサー"]
        next unless fixer_data && fixer_data[:effects]

        multiplier = fixer_data[:effects][slot.max_level]
        next unless multiplier

        if slot.slot_number == 11
          (1..5).each { |n| fixer_multipliers[n] = multiplier }
        elsif slot.slot_number == 12
          (6..10).each { |n| fixer_multipliers[n] = multiplier }
        end
      end
    end

    # Normalスロットの効果を計算
    normal_slots.each do |slot|
      memory_id = assignments[slot.id]
      next unless memory_id

      memory = all_memories.find { |m| m.id == memory_id }
      next unless memory

      skills_text = memory.tuning_skill
      next if skills_text.nil?

      skills = skills_text.split(/、|,/).map(&:strip)
      level = slot.max_level

      skills.each do |skill_name|
        skill_info = TuningSkillCalculator.skill_data[skill_name]
        next unless skill_info && skill_info[:effects]

        effect_value = skill_info[:effects][level]
        next unless effect_value

        # フィクサーの倍率を適用
        if fixer_multipliers[slot.slot_number]
          multiplier = fixer_multipliers[slot.slot_number]
          if TuningSkillCalculator::MULTIPLICATIVE_SKILLS.include?(skill_name)
            effect_value = 1.0 + (effect_value - 1.0) * multiplier
          else
            effect_value *= multiplier
          end
        end

        # 効果を合算
        if total_effects[skill_name]
          if TuningSkillCalculator::MULTIPLICATIVE_SKILLS.include?(skill_name)
            total_effects[skill_name][:value] *= effect_value
          else
            total_effects[skill_name][:value] += effect_value
          end
        else
          total_effects[skill_name] = {
            description: skill_info[:description],
            value: effect_value
          }
        end
      end
    end

    total_effects
  end

  def self.calculate_score(effects, target_skills)
    score = 0.0

    target_skills.each do |skill_name|
      next unless effects[skill_name]

      value = effects[skill_name][:value]

      # 倍率系スキルの場合、基準値からの差分を評価
      if TuningSkillCalculator::MULTIPLICATIVE_SKILLS.include?(skill_name)
        # 1.0からの差分をパーセントに変換して加算
        # 例: 1.05 -> 5.0点, 0.95 -> 5.0点（防御力は小さいほど良い）
        if skill_name.include?("防御力")
          # 防御力は小さいほど良い
          score += (1.0 - value).abs * 1000
        else
          # 攻撃力やリロードは大きいほど良い（リロードは小さいほど良いが値は0.9x形式）
          if skill_name.include?("リロード")
            score += (1.0 - value).abs * 1000
          else
            score += (value - 1.0).abs * 1000
          end
        end
      else
        # 加算系スキル（HP、GPなど）は実数値をそのまま加算
        score += value
      end
    end

    score
  end
end
