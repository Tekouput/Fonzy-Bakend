class StoreTransaction < ApplicationRecord
  belongs_to :requester, class_name: 'User'
  belongs_to :store

  def sanitize_attributes
    begin
      {
          id: id,
          status: status,
          store: store.simple_info,
          requester: requester.simple_info
      }
    rescue => e
      e
    end
  end

end
