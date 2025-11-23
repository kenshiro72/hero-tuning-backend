class Api::V1::MemoriesController < ApplicationController
  def index
    @memories = Memory.all.includes(:character)
    render json: @memories.as_json(include: :character)
  end

  # GET /api/v1/memories/special_skills
  # 全てのスペシャルチューニングスキルのリストを返す
  def special_skills
    skills = Memory.distinct.pluck(:special_tuning_skill).compact.sort
    render json: { special_skills: skills }
  end
end
