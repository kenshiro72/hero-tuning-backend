class Api::V1::CostumesController < ApplicationController
  def index
    @costumes = Costume.all.includes(:character, :slots)
    render json: @costumes.as_json(
      include: {
        character: {},
        slots: {}
      }
    )
  end
end
