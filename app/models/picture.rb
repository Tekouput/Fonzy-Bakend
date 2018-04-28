class Picture < ApplicationRecord
  belongs_to :owner, polymorphic: true, optional: true
  belongs_to :owner_main, polymorphic: true, optional: true

  has_attached_file :image, styles: { big: "500x500>", medium: "300x300>", thumb: "100x100>" }, default_url: "/images/missing.png", size: { less_than: 40.megabytes }
  validates_attachment_content_type :image, content_type: /\Aimage\/.*\z/

  def images
    {id: self.id, big: self.image.url(:big), medium: self.image.url(:medium), thumb: self.image.url(:thumb)}
  end


end
