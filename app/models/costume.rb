class Costume < ApplicationRecord
  belongs_to :character
  has_many :slots
end
