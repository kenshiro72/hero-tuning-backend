class AddTuningSkillsToMemories < ActiveRecord::Migration[8.0]
  def change
    add_column :memories, :tuning_skill, :text
    add_column :memories, :special_tuning_skill, :string
  end
end
