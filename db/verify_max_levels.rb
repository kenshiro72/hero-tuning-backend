# C レアリティのコスチュームを確認
c_costume = Costume.find_by(rarity: "C")
puts "=== C レアリティ: #{c_costume.name} ==="
c_costume.slots.order(:slot_number).each do |slot|
  puts "Slot #{slot.slot_number} (#{slot.slot_type}): role=#{slot.role}, class=#{slot.slot_class}, max_level=#{slot.max_level}"
end

puts ""

# SR レアリティのコスチュームを確認
sr_costume = Costume.find_by(rarity: "SR")
puts "=== SR レアリティ: #{sr_costume.name} ==="
sr_costume.slots.order(:slot_number).each do |slot|
  puts "Slot #{slot.slot_number} (#{slot.slot_type}): role=#{slot.role}, class=#{slot.slot_class}, max_level=#{slot.max_level}"
end

puts ""

# PUR レアリティのコスチュームを確認
pur_costume = Costume.find_by(rarity: "PUR")
puts "=== PUR レアリティ: #{pur_costume.name} ==="
pur_costume.slots.order(:slot_number).each do |slot|
  puts "Slot #{slot.slot_number} (#{slot.slot_type}): role=#{slot.role}, class=#{slot.slot_class}, max_level=#{slot.max_level}"
end
