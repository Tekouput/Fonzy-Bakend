class StoresHairdresser < ApplicationRecord
  belongs_to :store
  belongs_to :hair_dresser
  belongs_to :confirmer, polymorphic: true

  def sanitize_attributes
    begin
      {
          id: self.id,
          status: self.status,
          store: self.store.simple_info,
          hair_dresser: self.hair_dresser.user.simple_info_dresser,
          confirmer: self.confirmer.class.name
      }
    rescue => e
      e
    end
  end

end
