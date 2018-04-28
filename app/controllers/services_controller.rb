class ServicesController < ApplicationController
  skip_before_action :authenticate_request, only: :show
  attr_accessor :resource

  def create
    begin
      @resource = nil
      set_resource_auth

      if @resource.nil?
        render json: {error: "User or store not found"}, status: :not_found
      else
        service = Service.new(
            name: params['name'],
            description: params['description'],
            price: params['price'],
            duration: params['duration']
        )
        @resource.services << service
        service.save!
        @resource.save!
        render json: service.sanitize_info, status: :created
      end
    rescue => e
      render json: {error: e}, status: :ok
    end
  end

  def show
    set_resource
    if @resource.nil?
      render json: {error: "It's possible that the especified user doesnt have an store or that the store doesnt exist"}, status: :not_found
    else
      render json: @resource.services.map(&:sanitize_info), status: :ok
    end
  end

  def destroy
    set_resource_auth
    @resource.services.find(params[:service_id]).destroy!
    render json: @resource.services.map(&:sanitize_info), status: :ok
  end

  private

  def set_resource
    (request.original_url.include? 'stores') ? (@resource = Store.find(params[:id])) : (@resource = HairDresser.find(params[:id]))
  end

  def set_resource_auth
    (request.original_url.include? 'stores') ? (@resource = current_user.stores.find(params[:id])) : (@resource = current_user.hair_dresser)
  end
end
