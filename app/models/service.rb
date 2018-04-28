class Service < ApplicationRecord
  belongs_to :watcher, polymorphic: true
  has_and_belongs_to_many :appointments

  def sanitize_info
    begin
      {
          id: id,
          name: name,
          description: description,
          price: price,
          duration: duration,
          watcher: {
              type: watcher.class.name,
              info: watcher.try(:simple_info)
          }
      }
    rescue => e
      e
    end
  end

end
