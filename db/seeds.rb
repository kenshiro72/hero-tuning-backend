require 'csv'

# Clear existing data
Slot.destroy_all
Memory.destroy_all
Costume.destroy_all
Character.destroy_all

# Create Character: 緑谷出久
midoriya = Character.create!(
  name: '緑谷出久',
  role: 'Strike',
  character_class: 'HERO',
  hp: 650,
  alpha_damage: 60,
  beta_damage: 75,
  gamma_damage: 100
)

# Create Memory for 緑谷出久
Memory.create!(
  character: midoriya,
  role: 'Strike',
  memory_class: 'HERO',
  effect: 'ワン・フォー・オール: 攻撃力とスピードが大幅に上昇'
)

# Read CSV file
csv_path = Rails.root.join('db', '緑谷出久_コスチュームデータ.csv')
csv_data = CSV.read(csv_path, headers: true, encoding: 'UTF-8')

# レアリティから星レベルとmax_levelを決定
def rarity_to_star_and_max_level(rarity)
  case rarity
  when 'C'
    { star_level: 0, max_level: 1 }
  when 'R'
    { star_level: 1, max_level: 2 }
  when 'SR'
    { star_level: 2, max_level: 3 }
  when 'PUR'
    { star_level: 3, max_level: 4 }
  else
    { star_level: 0, max_level: 1 }
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
  rarity_info = rarity_to_star_and_max_level(row['レアリティ'])

  costume = Costume.create!(
    character: midoriya,
    name: row['コスチューム名'],
    rarity: row['レアリティ'],
    star_level: rarity_info[:star_level]
  )

  # Normal Slots 1-10 を作成
  (1..10).each do |i|
    slot_value = row["Normal Slot #{i}"]
    next if slot_value.nil? || slot_value.strip.empty?

    slot_info = parse_slot(slot_value)

    Slot.create!(
      costume: costume,
      slot_number: i,
      slot_type: 'Normal',
      role: slot_info[:role],
      slot_class: slot_info[:slot_class],
      max_level: rarity_info[:max_level]
    )
  end

  # Special Slots 1-2 を作成
  (1..2).each do |i|
    slot_value = row["Special Slot #{i}"]
    next if slot_value.nil? || slot_value.strip.empty?

    slot_info = parse_slot(slot_value)

    Slot.create!(
      costume: costume,
      slot_number: 10 + i,  # Special Slot 1 → 11, Special Slot 2 → 12
      slot_type: 'Special',
      role: slot_info[:role],
      slot_class: slot_info[:slot_class],
      max_level: rarity_info[:max_level]
    )
  end

  puts "Created costume: #{costume.name} (#{costume.rarity}) with #{costume.slots.count} slots"
end

puts "\n=== Seed Data Summary ==="
puts "Characters: #{Character.count}"
puts "Costumes: #{Costume.count}"
puts "Slots: #{Slot.count}"
puts "Memories: #{Memory.count}"
puts "========================="
