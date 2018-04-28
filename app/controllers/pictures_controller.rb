class PicturesController < ApplicationController
  before_action :set_resource, except: :show
  skip_before_action :authenticate_request, only: :show

  def create
    begin
      picture = params[:picture]
      image = Picture.create!(image: picture)
      @resource.pictures << image
      @resource.save!
      show
    rescue => e
      render json: { error: e }, status: :ok
    end
  end

  def update
    begin
      picture = @resource.pictures.find(params[:picture_id])
      @resource.picture = picture
      @resource.save
      show
    rescue => e
      render json: { error: e }, status: :ok
    end
  end

  def destroy
    begin
      @resource.pictures.find(params[:picture_id]).destroy
      show
    rescue => e
      render json: {error: e}
    end
  end

  def show
    set_resource_public
    begin
      images = @resource.try(:pictures).map(&:images)
      render json: {main: @resource.try(:picture).try(:images) || images.first, images: images}, status: :ok
    rescue => e
      render json: { error: e }, status: :ok
    end
  end

  private


  def set_resource_public
    @resource = (request.original_url.include? 'stores') ? Store.find(params[:store_id]) : HairDresser.find(params[:dresser_id] || current_user.hair_dresser.id)
  end

  def set_resource
    @resource = (request.original_url.include? 'stores') ? current_store_auth : current_user.hair_dresser
  end

end
