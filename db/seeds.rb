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

# ===== Helper Methods =====

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
  elsif [ 'HERO', 'VILLAIN' ].include?(slot_class)
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

# コスチュームとスロットを作成
def create_costumes_for_character(character, csv_data)
  csv_data.each do |row|
    # コスチュームを作成
    rarity = row['レアリティ']
    star_level = rarity_to_star_level(rarity)

    costume = Costume.create!(
      character: character,
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

    puts "  Created costume: #{costume.name} (#{costume.rarity}) with #{costume.slots.count} slots"
  end
end

# ===== Load Costume Data for All Characters =====

# db/ ディレクトリ内の全ての *_コスチュームデータ.csv ファイルを検出
# macOSのUnicode正規化問題を回避するため、全CSVファイルをリストしてフィルタリング
all_csv_files = Dir.glob(Rails.root.join('db', '*.csv').to_s)
costume_csv_files = all_csv_files.select do |file|
  basename = File.basename(file)
  # "コスチューム" を含み、かつ設定ファイルではないものを選択
  basename.include?('コスチューム') &&
    !basename.include?('レアリティ') &&
    !basename.include?('キャラクターデータ') &&
    !basename.include?('チューニングスキル')
end

puts "\n=== Loading Costume Data ==="
puts "Found #{costume_csv_files.count} costume CSV files"

costume_csv_files.each do |csv_path|
  # ファイル名からキャラクター名を抽出
  # 例: "緑谷出久_コスチュームデータ.csv" → "緑谷出久"
  filename = File.basename(csv_path, '.csv')
  # "_コスチュームデータ" または "_コスチュームデータ" の前までを抽出
  character_name_from_file = filename.split('_コスチューム')[0]

  # Unicode正規化（macOSのNFD形式をNFC形式に変換）
  character_name_from_file = character_name_from_file.unicode_normalize(:nfc)

  puts "\nProcessing: #{filename}"

  # CSVデータを読み込み
  begin
    csv_data = CSV.read(csv_path, headers: true, encoding: 'UTF-8')
  rescue StandardError => e
    puts "  Error reading CSV file: #{e.message}"
    next
  end

  # キャラクター名でマッチするキャラクターを検索
  # ファイル名のキャラクター名を含む全てのキャラクターを取得
  # 例: "緑谷出久" → "緑谷出久（オリジナル）", "緑谷出久（フルバレット）" など

  # まずLIKEクエリで検索
  matching_characters = Character.where("name LIKE ?", "%#{character_name_from_file}%")

  # 見つからない場合、全キャラクターを取得してRubyレベルでマッチング
  if matching_characters.empty?
    all_characters = Character.all
    matching_characters = all_characters.select do |char|
      char.name.include?(character_name_from_file)
    end
  end

  if matching_characters.empty?
    puts "  Warning: No character found matching '#{character_name_from_file}'. Skipping."
    puts "  Debug: Extracted name = '#{character_name_from_file}' (#{character_name_from_file.bytes.inspect})"
    next
  end

  # マッチしたキャラクターのうち、最初のもの（通常は「オリジナル」など）にコスチュームを作成
  # 複数バリアントがある場合は最初のものを使用
  character = matching_characters.is_a?(Array) ? matching_characters.first : matching_characters.first
  puts "  Matched character: #{character.name}"

  # コスチュームとスロットを作成
  create_costumes_for_character(character, csv_data)

  puts "  Completed for #{character.name}"
end

puts "\n=== Seed Data Summary ==="
puts "Characters: #{Character.count}"
puts "Costumes: #{Costume.count}"
puts "Slots: #{Slot.count}"
puts "Memories: #{Memory.count}"
puts "========================="
