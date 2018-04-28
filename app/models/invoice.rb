class Invoice < ApplicationRecord
  belongs_to :emitter, polymorphic: true
  belongs_to :appointment

  def get_amount
    total = 0
    appointment.services.each do |s|
      total += s.price
    end
    total
  end

  def sanitize_parameters
    begin
      total = 0
      appointment.services.each do |s|
        total += s.price
      end

      {
          id: id,
          extra_description: description,
          emitter: emitter.try(:simple_info),
          services_title: appointment.services.map(&:name),
          created_at: created_at,
          amount: {
              raw: total,
              formatted: format("$%.2f", total),
              after_tax: {
                  raw: "On progress",
                  formatted: "On progress"
              }
          },
          payment_method: {
              flag: payment_method,
              text: case payment_method
                      when 0
                        'cash'
                      else
                        'electronic'
                    end
          },
          payment: {
              identifier: (payment_method == 0) ? 'cash' : stripe_id,
              data: ((Stripe::Charge.retrieve stripe_id) if stripe_id)
          }
      }
    rescue => e
      e
    end
  end
end
