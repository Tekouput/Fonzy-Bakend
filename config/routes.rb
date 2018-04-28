Rails.application.routes.draw do

  post '/authenticate', to: 'authentication#authenticate'
  get '/user/:provider/token', to: 'authentication#omniauth'
  get '/instagram-feed', to: 'application#instagram_pictures'
  get '/address', to: 'application#get_address'
  post '/notify-device-token', to: 'application#change_token'

  scope '/find' do
    get '/list', to: 'stores#show_list'
    get '/places', to: 'stores#show_filtered'
    get '/user', to: 'application#query_user'
    get '/hairdresser', to: 'application#query_dresser'
  end

  resource :users
  resource :stores

  scope :users do

    get '/profile', to: 'users#show_public'

    scope '/hairdressers' do
      scope '/stores' do
        get '/', to: 'users#show_shops'
        put '/', to: 'users#append_dresser'
        delete '/', to: 'users#unbind_dresser'
        patch '/confirmation', to: 'users#confirmation_set'
      end

      patch '/bind', to: 'users#bind_hair_dresser'
      delete '/bind', to: 'users#unbind_hair_dresser'

      resource :services
      resource :clients
      resource :bookings
      resource :pictures
    end

    scope '/timetable' do
      get '/', to: 'users#get_timetable'
      get '/day', to: 'users#get_a_time_table'
      post '/time_section', to: 'users#modify_timetable'
      post '/time_section', to: 'stores#modify_timetable'
      delete '/time_section', to: 'users#delete_time_section'
      post '/collision', to: 'users#collision_check'
      post '/break', to: 'users#add_break'
      delete '/break', to: 'users#delete_break'
      post '/absence', to: 'users#add_absence'
      delete '/absence', to: 'users#delete_absence'
    end

    scope '/bookings' do
      get '/', to: 'users#bookings'
      post '/new', to: 'users#add_booking'
      delete '/deactive', to: 'users#remove_booking'
      patch :confirm, to: 'bookings#confirm'
      get :confirm, to: 'bookings#show_confirmations'
    end

    scope '/bookmark' do
      get '/', to: 'users#get_bookmark'
      post '/:type', to: 'users#add_bookmark'
      delete '/', to: 'users#remove_bookmark'
    end

    scope '/images' do
      post '/', to: 'users#add_image'
      delete '/', to: 'users#remove_image'
      patch '/', to: 'users#change_image'
    end

    scope '/payments' do
      scope '/methods' do
        get '/cards', to: 'invoice#get_cards'
        get '/card', to: 'invoice#get_card'
        post '/card', to: 'invoice#append_card'
        patch '/card', to: 'invoice#update_card'
        put '/card', to: 'invoice#change_default'
        delete '/card', to: 'invoice#delete_card'
      end
    end

  end

  scope '/invoice' do
    patch '/pay', to: 'invoice#update'
    #patch '/refund', to: 'invoice#destroy'
    #get '/info', to: 'invoice#show'
    post '/key', to: 'invoice#ephemeral_key'
  end

  scope :stores do
    get '/all_info', to: 'stores#show_all'

    scope '/hairdressers' do
      get '/', to: 'stores#show_dressers'
      put '/', to: 'stores#append_dresser'
      delete '/', to: 'stores#unbind_dresser'
      patch '/confirmation', to: 'stores#confirmation_set'
    end

    scope '/timetable' do
      get '/day', to: 'stores#get_a_time_table'
      post '/time_section', to: 'stores#modify_timetable'
      patch '/time_section', to: 'stores#update_time_section'
      delete '/time_section', to: 'stores#delete_time_section'
      post '/collision', to: 'stores#collision_check'
      post '/break', to: 'stores#add_break'
      delete '/break', to: 'stores#delete_break'
    end

    resource :services
    resource :clients
    resource :bookings
    resource :store_transactions do
      patch :confirm
    end
    resource :pictures
  end
end
