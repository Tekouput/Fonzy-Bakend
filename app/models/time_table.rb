class TimeTable < ApplicationRecord
  has_many :time_sections
  has_many :absences
  belongs_to :handler, polymorphic: true
end
