# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_08_090129) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "characters", force: :cascade do |t|
    t.string "name"
    t.string "role"
    t.string "character_class"
    t.integer "hp"
    t.integer "alpha_damage"
    t.integer "beta_damage"
    t.integer "gamma_damage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "costumes", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.string "name"
    t.string "rarity"
    t.integer "star_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_costumes_on_character_id"
  end

  create_table "memories", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.string "role"
    t.string "memory_class"
    t.text "effect"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "tuning_skill"
    t.string "special_tuning_skill"
    t.index ["character_id"], name: "index_memories_on_character_id"
  end

  create_table "slots", force: :cascade do |t|
    t.bigint "costume_id", null: false
    t.integer "slot_number"
    t.string "slot_type"
    t.string "role"
    t.string "slot_class"
    t.integer "max_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "equipped_memory_id"
    t.integer "current_level", default: 1, null: false
    t.index ["costume_id"], name: "index_slots_on_costume_id"
  end

  add_foreign_key "costumes", "characters"
  add_foreign_key "memories", "characters"
  add_foreign_key "slots", "costumes"
  add_foreign_key "slots", "memories", column: "equipped_memory_id"
end
