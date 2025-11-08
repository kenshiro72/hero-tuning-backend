class Character < ApplicationRecord
  has_many :costumes
  has_one :memory
end
