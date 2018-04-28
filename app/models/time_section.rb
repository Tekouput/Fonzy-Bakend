class TimeSection < ApplicationRecord
  belongs_to :time_table
  has_many :breaks

  def sanitize_attributes
    begin
      {
          id: self.id,
          day: self.day,
          init: self.init,
          end: self.end
      }
    rescue => e
      e
    end
  end

end
