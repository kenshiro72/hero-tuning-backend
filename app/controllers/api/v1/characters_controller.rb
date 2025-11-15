class Api::V1::CharactersController < ApplicationController
  def index
    @characters = Character.all
    render json: @characters
  end

  def show
    @character = Character.includes(costumes: { slots: { equipped_memory: :character } }, memory: {}).find(params[:id])
    render json: @character.as_json(
      include: {
        costumes: {
          include: {
            slots: {
              include: {
                equipped_memory: {
                  include: {
                    character: { only: [:id, :name] }
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

  # POST /api/v1/characters/:id/optimize
  def optimize
    character = Character.includes(costumes: :slots).find(params[:id])
    custom_skills = params[:custom_skills]
    special_slot_1_skill = params[:special_slot_1_skill]
    special_slot_2_skill = params[:special_slot_2_skill]
    special_slot_either_skill = params[:special_slot_either_skill]

    unless custom_skills && custom_skills.any?
      return render json: { error: "custom_skills must be provided" }, status: :bad_request
    end

    # モードを判定
    filter_mode = determine_filter_mode(special_slot_1_skill, special_slot_2_skill, special_slot_either_skill)

    # eitherモードの場合、special_slot_1_skillに値を設定
    if filter_mode == 'either'
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

  def determine_filter_mode(slot_1, slot_2, either)
    if either.present?
      'either'
    elsif slot_1.present? && slot_2.present?
      'both'
    elsif slot_1.present?
      'special_1'
    elsif slot_2.present?
      'special_2'
    else
      'none'
    end
  end
end
