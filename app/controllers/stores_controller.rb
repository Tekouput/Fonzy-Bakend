class StoresController < ApplicationController
  skip_before_action :authenticate_request, only: %i[show show_images show_filtered show_all show_list show_dressers]

  def create
    store = Store.new(name: params[:name], longitude: params[:longitude], latitude: params[:latitude], zip_code: params[:zip_code], description: params[:description], style: params[:style])
    store.owner = current_user
    store.save!

    current_user.is_shop_owner = true
    current_user.save!

    if store
      render json: store.simple_info, status: :created
    else
      render json: { error: 'Resource can not be created' }, status: :bad_request
    end
  end

  def show
    if params[:maps]
      render json: Store.retrieve_from_google(params[:store_id]), status: :ok
    else
      render json: current_store.to_json(methods: [:reverse_geocode]), status: :ok
    end
  end

  def show_list
    render json: Store.all.paginate(page: params[:page]).order(created_at: :asc), status: :ok
  end

  def show_all
    begin
      render json: { basic_info: current_store.simple_info, hairdressers: current_store.users.all, services: current_store.services.map {|ser| ser.sanitize_info}, photos: current_store.pictures.map {|pic| pic.images}, owner: current_store.owner.sanitize_atributes }, code: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def show_filtered
    latitude = params['latitude']
    longitude = params['longitude']
    distance_break = params['distance_break']
    style = params['style']

    local_stores = Store.near([latitude, longitude], distance_break).where("style LIKE ?", "#{style}")
    places_stores = Store.near_by_google(latitude, longitude, distance_break, style)
    independents = HairDresser.near([latitude, longitude], distance_break).where(is_independent: true)

    local_stores = Store.open_at(DateTime.parse(params[:open_at]), local_stores) if params[:open_at].present?
    local_stores = Store.open_at_time(params[:time], local_stores) if params[:time].present?
    local_stores = Store.open_at_day(params[:day], local_stores) if params[:day].present?
    local_stores = Store.average_price(params[:price], local_stores) if params[:price].present?
    local_stores = Store.get_by_city(params[:city], local_stores) if params[:city].present?

    independents = HairDresser.open_at(DateTime.parse(params[:open_at]), independents) if params[:open_at].present?
    independents = HairDresser.open_at_time(params[:time], independents) if params[:time].present?
    independents = HairDresser.open_at_day(params[:day], independents) if params[:day].present?
    independents = HairDresser.average_price(params[:price], independents) if params[:price].present?
    independents = HairDresser.get_by_city(params[:city], independents) if params[:city].present?


    stores = local_stores.to_a
    maps = []
    places_stores.each do |str|
      maps << str unless Store.contains(stores, str['id'])
    end

    independents = independents.map {|idepe| {dresser_info: idepe.user.simple_info_dresser, hairdresser_user: User.sanitize_atributes(idepe.user_id)}}

    render json: { stores: stores, independents: independents, google_maps: maps }, status: :ok
  end

  def update
    store = current_store_auth
    if store
      store.name = params[:name]
      store.longitude = params[:longitude]
      store.latitude = params[:latitude]
      store.zip_code = params[:zip_code]
      store.description = params[:description]
      store.style = params[:style]
      store.save! ? (render json: store.simple_info, status: :ok) : (render json: { error: 'Error occurred while saving changes' }, status: :bad_request)
    else
      render json: { error: 'Error occurred while saving changes' }, status: :bad_request
    end
  end

  # Dresser system methods.

  def show_dressers
    begin
      render json: StoresHairdresser.where(store: current_store).map {|h| {request: h, hair_dresser_user: User.sanitize_attributes_user(HairDresser.find(h.hair_dresser_id).user)}}, status: :ok
    rescue => e
      render json: {error: e, store: current_store}, status: :bad_request
    end
  end

  def confirmation_set
    begin
      store = current_store_auth
      hair_dresser = HairDresser.find params[:dresser_id]
      confirmation = StoresHairdresser.where(store: store, hair_dresser: hair_dresser, confirmer: store).first
      if confirmation.status == 0
        confirmation.status = (params[:accept] == 'true' ? 1 : 2)
        confirmation.save!
      end
      render json: StoresHairdresser.where(store: store), status: :ok
    rescue => e
      render json: { error: e }, status: :bad_request
    end
  end

  def append_dresser
    store = current_store_auth
    success = false
    if store
      hair_dresser = HairDresser.find params[:dresser_id]
      if hair_dresser
        unless StoresHairdresser.where(store: store, hair_dresser: hair_dresser).size > 0
          sh = StoresHairdresser.new(
            store: store,
            hair_dresser: hair_dresser,
            confirmer: hair_dresser
          )
          sh.save!
          success = true
        end
      else
        success = false
      end
    end

    if success
      render json: StoresHairdresser.where(store: store).map(&:sanitize_attributes), status: :ok
    else
      render json: { error: 'Invalid request' }, status: :bad_request
    end
  end

  def unbind_dresser
    begin
      store = current_store_auth
      hair_dresser = HairDresser.find params[:dresser_id]
      StoresHairdresser.where(store: store, hair_dresser: hair_dresser).first.destroy!
      render json: StoresHairdresser.where(store: store).map(&:sanitize_attributes), status: :ok
    rescue => e
      render json: { error: e}, status: :bad_request
    end
  end

  # Time table methods
  def get_a_time_table
    begin

      start_date = params[:s_day] || Time.now
      end_date = params[:e_day] || Time.now + 7.days

      p start_date, end_date

      time_table = current_store.time_table
      time_sections = time_table.time_sections.select {|tt| tt.day ? (params[:day].include? tt.day.to_s) : false}
      breaks = time_sections.each {|ts| ts.breaks}
      absences = time_table.absences.where("day >= ? AND day <= ?", start_date, end_date)
      render json: {time_sections: time_sections, breaks: breaks, absences: absences}, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def modify_timetable
    collides = collision_with_day? params[:timetable_params][:content]
    if !(collides)[:collision]
      tt = add_a_timetable(params[:timetable_params][:content])
      render json: tt, status: :ok
    else
      render json: collides, status: :conflict
    end
  end

  def update_time_section
    begin
      time_section = current_store_auth.time_table.time_sections.find(params[:time_section_id])
      time_section.update!(params[:time_section_params].permit!)
      render json: time_section, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def delete_time_section
    begin
      store = current_store_auth
      (store.time_table.time_sections.find params[:id]).destroy!
      render json: {}, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def collision_check
    begin
      collides = collision_with_day? params[:timetable_params][:content]
      render json: collides, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def add_break
    begin
      time_sectio = current_store_auth.time_table.time_sections.find params[:time_section_id]
      time_sectio.breaks << Break.create!(day: params['day'],
                                          init: params['init'],
                                          duration: params['duration'],
                                          time_section: time_sectio)
      render json: time_sectio.breaks, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def delete_break
    begin
      time_sectio = current_store_auth.time_table.time_sections.find params[:time_section_id]
      break_ = time_sectio.breaks.find params[:break_id]
      break_.destroy!
      render json: time_sectio.breaks, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  private

  def add_a_timetable(content)

    c_store = current_store_auth

    unless c_store.time_table
      c_store.time_table = TimeTable.create!(handler: c_store)
    end

    tt = TimeSection.create!(day: content['day'],
                             init: content['init'],
                             end: content['end'],
                             time_table: c_store.time_table)

    c_store.time_table.time_sections << tt
    tt
  end

  def collision_with_day?(content)
    c_store = current_store_auth

    init = content['init']
    fin = content['end']
    time_table = c_store.time_table || c_store.create_time_table

    if time_table
      time_table.time_sections.where(day: content['day']).each do |ts|
        if  (init <= ts.init && fin > ts.init) ||
            (fin >= ts.end && init < ts.end) ||
            (init >= ts.init && fin <= ts.end) ||
            (init <= ts.init && fin >= ts.end)
          p true
          return {collision: true, cause: ts}
        else
          return {collision: false, cause: nil}
        end
      end
      {collision: false, cause: nil}
    else
      {collision: false, cause: nil}
    end
  end
end
