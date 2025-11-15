require 'csv'

# Clear existing data
Slot.destroy_all
Memory.destroy_all
Costume.destroy_all
Character.destroy_all

# Read character data CSV
character_csv_path = Rails.root.join('db', 'キャラクターデータ.csv')
character_data = CSV.read(character_csv_path, headers: true, encoding: 'UTF-8')

# Create Characters and Memories from CSV
character_data.each do |row|
  next if row['キャラクター名'].nil? || row['キャラクター名'].strip.empty?

  character = Character.create!(
    name: row['キャラクター名'],
    role: row['Role'],
    character_class: row['Class'],
    hp: row['最大HP'].to_i,
    alpha_damage: 0,  # デフォルト値
    beta_damage: 0,   # デフォルト値
    gamma_damage: 0   # デフォルト値
  )

  # Create Memory for this character
  Memory.create!(
    character: character,
    role: row['Role'],
    memory_class: row['Class'],
    tuning_skill: row['チューニングスキル'],
    special_tuning_skill: row['スペシャルチューニングスキル'],
    effect: "#{row['チューニングスキル']} / #{row['スペシャルチューニングスキル']}"
  )

  puts "Created character: #{character.name} (#{character.role})"
end

# 緑谷出久のコスチュームデータを読み込むために使用する
midoriya = Character.find_by(name: '緑谷出久（オリジナル）')

# Read CSV file
csv_path = Rails.root.join('db', '緑谷出久_コスチュームデータ.csv')
csv_data = CSV.read(csv_path, headers: true, encoding: 'UTF-8')

# レアリティから星レベルを決定
def rarity_to_star_level(rarity)
  case rarity
  when 'C'
    0
  when 'R'
    1
  when 'SR'
    2
  when 'PUR'
    3
  else
    0
  end
end

# Normal Slot の max_level を計算（slot_class に基づく）
def calculate_normal_slot_max_level(slot_class)
  if slot_class.nil?
    3  # Classなし → max_level: 3
  elsif ['HERO', 'VILLAIN'].include?(slot_class)
    4  # Class指定あり → max_level: 4
  else
    3  # デフォルト
  end
end

# Special Slot の max_level を計算（レアリティと slot_number に基づく）
def calculate_special_slot_max_level(rarity, slot_number)
  case rarity
  when 'C', 'R'
    slot_number == 11 ? 3 : 4
  when 'SR'
    slot_number == 11 ? 4 : 5
  when 'PUR'
    slot_number == 11 ? 10 : 11
  else
    3  # デフォルト
  end
end

# スロット値からロールとクラスを抽出
def parse_slot(slot_value)
  return nil if slot_value.nil? || slot_value.strip.empty?

  # (H) or (V) を抽出
  slot_class = nil
  role = slot_value.dup

  if role.include?('(H)')
    slot_class = 'HERO'
    role = role.gsub('(H)', '').strip
  elsif role.include?('(V)')
    slot_class = 'VILLAIN'
    role = role.gsub('(V)', '').strip
  end

  { role: role, slot_class: slot_class }
end

# Create Costumes and Slots
csv_data.each do |row|
  # コスチュームを作成
  rarity = row['レアリティ']
  star_level = rarity_to_star_level(rarity)

  costume = Costume.create!(
    character: midoriya,
    name: row['コスチューム名'],
    rarity: rarity,
    star_level: star_level
  )

  # Normal Slots 1-10 を作成
  (1..10).each do |i|
    slot_value = row["Normal Slot #{i}"]
    next if slot_value.nil? || slot_value.strip.empty?

    slot_info = parse_slot(slot_value)
    max_level = calculate_normal_slot_max_level(slot_info[:slot_class])

    Slot.create!(
      costume: costume,
      slot_number: i,
      slot_type: 'Normal',
      role: slot_info[:role],
      slot_class: slot_info[:slot_class],
      max_level: max_level
    )
  end

  # Special Slots 1-2 を作成
  (1..2).each do |i|
    slot_value = row["Special Slot #{i}"]
    next if slot_value.nil? || slot_value.strip.empty?

    slot_info = parse_slot(slot_value)
    slot_number = 10 + i  # Special Slot 1 → 11, Special Slot 2 → 12
    max_level = calculate_special_slot_max_level(rarity, slot_number)

    Slot.create!(
      costume: costume,
      slot_number: slot_number,
      slot_type: 'Special',
      role: slot_info[:role],
      slot_class: slot_info[:slot_class],
      max_level: max_level
    )
  end

  puts "Created costume: #{costume.name} (#{costume.rarity}) with #{costume.slots.count} slots"
end

# 緑谷出久 OFAのコスチュームデータを読み込む
midoriya_ofa = Character.find_by(name: '緑谷出久 OFA（オリジナル）')

if midoriya_ofa
  # Read CSV file for 緑谷出久 OFA
  csv_path_ofa = Rails.root.join('db', '緑谷出久_OFA_コスチュームデータ.csv')
  csv_data_ofa = CSV.read(csv_path_ofa, headers: true, encoding: 'UTF-8')

  # Create Costumes and Slots for 緑谷出久 OFA
  csv_data_ofa.each do |row|
    # コスチュームを作成
    rarity = row['レアリティ']
    star_level = rarity_to_star_level(rarity)

    costume = Costume.create!(
      character: midoriya_ofa,
      name: row['コスチューム名'],
      rarity: rarity,
      star_level: star_level
    )

    # Normal Slots 1-10 を作成
    (1..10).each do |i|
      slot_value = row["Normal Slot #{i}"]
      next if slot_value.nil? || slot_value.strip.empty?

      slot_info = parse_slot(slot_value)
      max_level = calculate_normal_slot_max_level(slot_info[:slot_class])

      Slot.create!(
        costume: costume,
        slot_number: i,
        slot_type: 'Normal',
        role: slot_info[:role],
        slot_class: slot_info[:slot_class],
        max_level: max_level
      )
    end

    # Special Slots 1-2 を作成
    (1..2).each do |i|
      slot_value = row["Special Slot #{i}"]
      next if slot_value.nil? || slot_value.strip.empty?

      slot_info = parse_slot(slot_value)
      slot_number = 10 + i  # Special Slot 1 → 11, Special Slot 2 → 12
      max_level = calculate_special_slot_max_level(rarity, slot_number)

      Slot.create!(
        costume: costume,
        slot_number: slot_number,
        slot_type: 'Special',
        role: slot_info[:role],
        slot_class: slot_info[:slot_class],
        max_level: max_level
      )
    end

    puts "Created costume for 緑谷出久 OFA: #{costume.name} (#{costume.rarity}) with #{costume.slots.count} slots"
  end
else
  puts "Warning: Character '緑谷出久 OFA（オリジナル）' not found. Skipping OFA costume data."
end

puts "\n=== Seed Data Summary ==="
puts "Characters: #{Character.count}"
puts "Costumes: #{Costume.count}"
puts "Slots: #{Slot.count}"
puts "Memories: #{Memory.count}"
puts "========================="
