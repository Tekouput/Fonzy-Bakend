class UsersController < ApplicationController
  skip_before_action :authenticate_request, only: [:create, :show_public]
  before_action :set_stripe_apy_key

  def create
    begin
      u = User.find_by_email params[:email]
      if u
        if u.password_digest.blank?
          u.update! password: params[:password], password_confirmation: params[:password_confirmation]
          stripe_customer = Stripe::Customer.create(
              description: "Customer for #{ u.email }"
          )
          u.stripe_id = stripe_customer.id
          u.save!
          render json: u.sanitize_atributes, status: :ok
        else
          render json: {error: 'User exist'}, status: :bad_request
        end
      else
        user = User.new email: params[:email], password: params[:password], password_confirmation: params[:password_confirmation]
        stripe_customer = Stripe::Customer.create(
                            description: "Customer for #{ user.email }"
        )
        user.stripe_id = stripe_customer.id
        if user.save
          render json: user.sanitize_atributes, status: :created
        else
          render json: {error: 'Error occurred review passwords or check logs'}, status: :bad_request
        end
      end
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def update
    begin
      user = current_user
      if user
        user.first_name = params[:first_name]
        user.last_name = params[:last_name]
        user.birth_date = params[:birth_day]
        user.sex = params[:sex]
        user.zip_code = params[:zip]
        user.phone_number = params[:phone_number]
        user.save! ? (render json: user.sanitize_atributes, status: :ok) : (render json: {error: 'Error occurred while saving changes'}, status: :bad_request)
      else
        render json: {error: 'Error occurred while saving changes'}, status: :bad_request
      end
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def show
    begin
      render json: current_user.sanitize_atributes, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def show_public
    begin
      render json: User.sanitize_atributes(params[:id]), status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  # Images

  def add_image
    begin
      user = current_user
      picture = params[:picture]
      image = Picture.create!(image: picture)
      user.pictures << image
      user.profile_pic = image.id
      user.save!
      render json: user.sanitize_atributes, status: :ok
    rescue => e
      render json: {error: e}, status: :ok
    end
  end

  def remove_image
    begin
      user = current_user
      user.profile_pic = ''
      user.save!
      render json: user.sanitize_atributes, status: :ok
    rescue => e
      render json: {error: e}, status: :ok
    end
  end

  # Hair dressser methods

  def bind_hair_dresser
    begin
      user = current_user
      if user
        hairdresser_info = HairDresser.new(
            is_independent: params[:is_independent],
            longitude: params[:longitude],
            latitude: params[:latitude],
            description: params[:description],
            online_payment: params[:online_payment],
            state: params[:state]
        )
        user.hair_dresser = hairdresser_info
        user.id_hairdresser = true
        user.save!

        hairdresser_info.reverse_geocode

        hairdresser_info.save! ? (render json: user.sanitize_atributes, status: :ok) : (render json: {error: 'Error occurred while saving changes'}, status: :bad_request)
      else
        render json: {error: 'Error occurred while saving changes'}, status: :bad_request
      end
    rescue => e
      render json: {error: e}, status: :ok
    end
  end

  def unbind_hair_dresser
    begin
      user = current_user
      user.hair_dresser = nil
      user.id_hairdresser = false
      user.save!
      render json: user.sanitize_atributes, status: :ok
    rescue => e
      render json: {error: e}, status: :ok
    end
  end

  # Hairdresser system methods.

  def show_shops
    begin
      render json: StoresHairdresser.where(hair_dresser: current_user.hair_dresser).map {|sh| sh.sanitize_attributes}, status: :ok
    rescue => e
      render json: {error: e, user: current_user.sanitize_atributes}, status: :bad_request
    end
  end

  def confirmation_set
    begin
      store = Store.find params[:store_id]
      hair_dresser = current_user.hair_dresser
      confirmation = StoresHairdresser.where(store: store, hair_dresser: hair_dresser, confirmer: hair_dresser).first
      if confirmation.status == 0
        confirmation.status = (params[:accept] == 'true' ? 1 : 2)
        confirmation.save!
      end
      render json: StoresHairdresser.where(hair_dresser: hair_dresser).map {|sh| sh.sanitize_attributes}, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def append_dresser
    begin
      store = Store.find params[:store_id]
      hair_dresser = current_user.hair_dresser
      if !(StoresHairdresser.where(store: store, hair_dresser: hair_dresser).size > 0)
        sh = StoresHairdresser.new(
            store: store,
            hair_dresser: hair_dresser,
            confirmer: store
        )
        sh.save!
        render json: StoresHairdresser.where(hair_dresser: hair_dresser).map {|sh| sh.sanitize_attributes}, status: :ok
      else
        render json: {message: 'User already appended'}, status: :not_modified
      end
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def unbind_dresser
    begin
      store = Store.find params[:store_id]
      hair_dresser = current_user.hair_dresser
      StoresHairdresser.where(store: store, hair_dresser: hair_dresser).first.destroy!
      render json: StoresHairdresser.where(hair_dresser: hair_dresser).map {|sh| sh.sanitize_attributes}, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  # Timetable methods

  def get_timetable
    begin
      hair_dresser = HairDresser.find_by(id: params[:dresser_id]) || current_user.hair_dresser
      render json: hair_dresser.time_table.time_sections.map {|hts| hts.sanitize_attributes}, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def get_a_time_table
    begin
      start_date = params[:s_day] || Time.now
      end_date = params[:e_day] || Time.now + 7.days

      p start_date, end_date

      hair_dresser = (HairDresser.find params[:h_id])
      time_table = hair_dresser.time_table || hair_dresser.create_time_table
      time_sections = time_table.time_sections.where(day: params[:day])
      breaks = time_sections.each(&:breaks)
      absences = time_table.absences.where("day >= ? AND day <= ?", start_date, end_date)
      render json: {time_sections: time_sections.map {|hts| hts.sanitize_attributes}, breaks: breaks, absences: absences}, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def modify_timetable
    begin
      collides = collision_with_day? params[:timetable_params][:content]
      if !(collides)[:collision]
        tt = add_a_timetable(params[:timetable_params][:content])
        render json: tt, status: :ok
      else
        render json: collides, status: :conflict
      end
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def update_time_section
    begin
      time_section = current_user.hair_dresser.time_table.time_sections.find(params[:time_section_id])
      time_section.update!(params[:time_section_params].permit!)
      render json: time_section.sanitize_attributes, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def delete_time_section
    user = current_user
    begin
      (user.hair_dresser.time_table.time_sections.find params[:id]).destroy!
      render json: user.hair_dresser.time_table.time_sections.map {|sth| sth.sanitize_attributes}, status: :ok
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
      time_sectio = current_user.hair_dresser.time_table.time_sections.find params[:time_section_id]
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
      time_sectio = current_user.hair_dresser.time_table.time_sections.find params[:time_section_id]
      break_ = time_sectio.breaks.find params[:break_id]
      break_.destroy!
      render json: time_sectio.breaks, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def add_absence
    begin
      time_table = current_user.hair_dresser.time_table || current_user.hair_dresser.create_time_table
      time_table.absences << Absence.create!(day: params['day'],
                                             init: params['init'],
                                             duration: params['duration'],
                                             time_table: time_table)
      render json: time_table.absences, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def delete_absence
    begin
      (current_user.hair_dresser.time_table.absences.find params[:absence_id]).destroy!
      render json: current_user.hair_dresser.time_table.absences, status: :ok
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  # Bookmarks methods

  def get_bookmark
    entities = []
    for bm in current_user.bookmarks
      if bm.entity
      entity = bm.entity
      address = JSON.parse(entity.address.to_json) if entity.address
      bm_entity = {}.as_json
      bm_entity[:id] = bm.id
      bm_entity[:entity_id] = entity.id
      if entity.class == HairDresser
        bm_entity[:name] = "#{entity.user.first_name} #{entity.user.last_name}"
        bm_entity[:type] = 'HairDresser'
        bm_entity[:profile_picture] = entity.try(:picture).try(:images) || entity.try(:pictures).try(:first).try(:images)
        bm_entity[:address] = "#{address['city']}, #{address['country']}" if address
        bm_entity[:rating] = entity.rating
      else
        bm_entity[:name] = entity.name
        bm_entity[:type] = 'Store'
        bm_entity[:profile_picture] = entity.try(:picture).try(:images) || entity.try(:pictures).try(:first).try(:images)
        bm_entity[:address] = "#{address['city']}, #{address['country']}" if address
        bm_entity[:rating] = entity.ratings
      end
      entities << bm_entity
        end
    end
    render json: entities, status: :ok
  end

  def add_bookmark
    begin
      type = params[:type]
      id = params[:entity_id]
      entity = (type.eql? 'hairdresser') ? (HairDresser.find id) : (Store.find id)

      bm = Bookmark.new(
          user: current_user,
          entity: entity
      )

      current_user.bookmarks << bm unless (current_user.bookmarks.where(user: current_user, entity: entity).size > 0)

      get_bookmark
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def remove_bookmark
    begin
      (current_user.bookmarks.find params[:id_bookmark]).destroy!
      get_bookmark
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  # Bookings methods

  def bookings
    begin
      render json: current_user.appointments.map {|cua| cua.sanitize_attributes}
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def add_booking
    begin
      type = params[:type]
      id = params[:entity_id]

      appointment = Appointment.create!(
        handler: (type.eql? 'hairdresser') ? (HairDresser.find id) : (Store.find id),
        user: current_user,
        services: (Service.find params[:services_id]),
        book_time: params[:book_time],
        book_notes: params[:book_notes],
        book_date: params[:book_date],
        state: true
      )

      Invoice.create!(
        #description: params[:description],
        emitter: appointment.handler,
        appointment: appointment,
        payment_method: params[:payment_method]
      )

      bookings

    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  def remove_booking
    begin
      booking = (current_user.appointments.find params[:booking_id])
      booking.state = false
      booking.save!
      bookings
    rescue => e
      render json: {error: e}, status: :bad_request
    end
  end

  private

  def add_a_timetable(content)
    user_t = current_user.hair_dresser

    unless user_t.time_table
      user_t.time_table = TimeTable.create!(handler: user_t)
    end

    tt = TimeSection.create!(day: content['day'],
                             init: content['init'],
                             end: content['end'],
                             time_table: user_t.time_table)

    user_t.time_table.time_sections << tt
    tt.sanitize_attributes
  end

  def collision_with_day?(content)
    user = current_user

    init = content['init']
    fin = content['end']
    time_table = user.hair_dresser.time_table || user.hair_dresser.create_time_table

    if time_table
      time_table.time_sections.where(day: content['day']).each do |ts|
        if (init <= ts.init && fin > ts.init) ||
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
