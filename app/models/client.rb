class Client < ApplicationRecord
  belongs_to :user
  belongs_to :lister, polymorphic: true

  def sanitize_attributes
    begin
      {
          id: id,
          note: note,
          user: user.simple_info,
          lister: {
              type: lister.class.name,
              info: lister.simple_info
          }
      }
    rescue => e
      e
    end
  end

end
