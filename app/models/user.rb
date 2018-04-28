class User < ApplicationRecord
  has_secure_password
  has_many :stores, as: :owner
  has_many :services, as: :watcher
  has_one :hair_dresser, dependent: :destroy
  has_many :appointments
  has_many :bookmarks
  has_many :bookings_requests
  has_many :pictures, as: :owner

  geocoded_by :last_ip do |obj, results|
    if geo = results.first
      obj.last_location = "#{geo.city}, #{geo.country}"
    end
      p results.first
  end

  scope :filter_name, -> (name) { where("concat_ws(' ', first_name, last_name) like ?", "%#{name}%").limit(50)}
  scope :filter_dresser, -> (name) { where("concat_ws(' ', first_name, last_name) like ? AND LENGTH(id_hairdresser) > 0", "%#{name}%").limit(50)}



  def self.sanitize_atributes(id)
    user = User.find(id)
    clean_user = {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      sex: user.sex,
      birth_day: user.birth_date,
      profile_picture: user.pictures.where(id: user.profile_pic).try(:first).try(:images),
      phone_number: user.phone_number,
      email: user.email,
      stores: user.stores.all,
      hairdresser_information: user.hair_dresser
    }
    clean_user
  end

  def self.sanitize_attributes_user(user)
    clean_user = {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        sex: user.sex,
        birth_day: user.birth_date,
        profile_picture: Picture.find_by(id: user.profile_pic).try(:images) || user.profile_pic,
        phone_number: user.phone_number,
        email: user.email,
        stores: user.stores.all,
        hairdresser_information: user.hair_dresser
    }
    clean_user
  end

  def sanitize_atributes
    user = self
    {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        sex: user.sex,
        birth_day: user.birth_date,
        profile_picture: Picture.find_by(id: user.profile_pic).try(:images) || user.profile_pic,
        phone_number: user.phone_number,
        email: user.email,
        stores: user.stores.all,
        hairdresser_information: user.hair_dresser
    }
  end

  def simple_info
    user = self
    {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        sex: user.sex,
        profile_picture: Picture.find_by(id: user.profile_pic).try(:images) || {id: -1, big: user.profile_pic, medium: user.profile_pic, thumb: user.profile_pic},
        address: user.last_location,
        email: user.email,
        phone: user.phone_number
    }
  end

  def simple_info_dresser
    begin
    user = self
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
