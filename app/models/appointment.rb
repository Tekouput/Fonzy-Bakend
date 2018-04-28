class Appointment < ApplicationRecord
  has_and_belongs_to_many :services
  belongs_to :handler, polymorphic: true
  belongs_to :user
  has_one :invoice

  def sanitize_attributes
    begin
    booking = self
    {
        id: booking.id,
        state: booking.state,
        book_time: booking.book_time,
        book_note: booking.book_notes,
        book_date: booking.book_date,
        services: booking.services.map(&:sanitize_info),
        handler: {
            type: booking.handler.class.name,
            info: booking.handler.try(:simple_info)
        },
        user: booking.user.simple_info,
        invoice: invoice.try(:sanitize_parameters)
    }
    rescue => e
      e
    end
  end

end
