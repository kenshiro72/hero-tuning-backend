class Api::V1::MemoriesController < ApplicationController
  def index
    @memories = Memory.all.includes(:character)
    render json: @memories.as_json(include: :character)
  end
end
