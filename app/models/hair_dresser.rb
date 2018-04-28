class HairDresser < ApplicationRecord
  belongs_to :user

  has_many :pictures, as: :owner
  has_one :picture, as: :owner_main

  has_many :services, as: :watcher
  has_many :appointments, as: :handler
  reverse_geocoded_by :latitude, :longitude do |obj, results|
      if geo = results.first
        pr = {
            city: geo.city,
            state: geo.state,
            zipcode: geo.postal_code,
            country: geo.country,
            address: geo.address_components
        }
        obj.address = pr
      end
  end
  after_validation :reverse_geocode
  has_one :time_table, as: :handler
  has_many :bookmarks, as: :entity

  has_many :stores_hairdressers
  has_many :stores, through: :stores_hairdressers
  has_many :stores_hairdressers, as: :confirmer

  has_many :clients, as: :lister
  has_many :users, through: :clients

  has_many :bookings_requests, as: :handler
  has_many :users, through: :bookings_requests

  has_many :invoice, as: :emitter


  def self.open_at(time, stores)
    open_stores = []
    stores.each do |st|
      time_sections = st.try(:time_table).try(:time_sections)
      if time_sections
        open_stores << st unless time_sections.where("day = ? AND init <= ? AND end >= ?", time.wday, time.seconds_since_midnight, time.seconds_since_midnight).empty?
      end
    end

    open_stores
  end

  def self.open_at_time(time, stores)
    open_stores = []
    stores.each do |st|
      time_sections = st.try(:time_table).try(:time_sections)
      if time_sections
        open_stores << st unless time_sections.where("init <= ? AND end >= ?", time, time).empty?
      end
    end

    open_stores
  end

  def self.open_at_day(day, stores)
    open_stores = []
    stores.each do |st|
      time_sections = st.try(:time_table).try(:time_sections)
      if time_sections
        open_stores << st unless time_sections.where("day = ?", day).empty?
      end
    end

    open_stores
  end

  def self.average_price(price, stores)
    interval_stores = []
    stores.each do |st|
      services = st.try(:services)
      next if services.size == 0

      price_interval = calculate_interval_of services
      interval_stores << st if price.to_f > price_interval[:give_low] && price.to_f < price_interval[:give_high]
    end

    interval_stores
  end

  def self.calculate_interval_of(services)
    media = 0
    services.each do |s|
      media += s.price.to_f
    end
    media = media / services.size
    varianza = 0
    services.each do |s|
      varianza = varianza + ((s.price.to_f - media)**2)
    end
    varianza = Math.sqrt( varianza / services.size )
    error = 0.9505 * (varianza / Math.sqrt(services.size))
    int = {
        give_low: media - error,
        give_high: media + error
    }
    p int
    int
  end

  def self.get_by_city(city, stores)
    city_stores = []

    stores.each do |s|
      next unless s.try(:address)
      city_stores << s if s.address['city'].downcase.include? city.downcase
    end

    city_stores
  end

  def simple_info
    begin
      user = self.user
      {
          id: user.hair_dresser.id,
          first_name: user.first_name,
          last_name: user.last_name,
          sex: user.sex,
          profile_picture: (user.hair_dresser.picture || user.hair_dresser.pictures.try(:first)).try(:images),
          address: user.hair_dresser.address,
          rating: user.hair_dresser.rating
      }
    rescue => e
      p e
    end
  end

end
