class Api::V1::CharactersController < ApplicationController
  def index
    @characters = Character.all
    render json: @characters
  end

  def show
    @character = Character.includes(costumes: :slots, memory: {}).find(params[:id])
    render json: @character.as_json(
      include: {
        costumes: {
          include: :slots
        },
        memory: {}
      }
    )
  end
end
