class StoreTransactionsController < ApplicationController

  def create
    store = Store.find params[:store_id]
    st = StoreTransaction.find_or_create_by!(
        requester: current_user,
        store: store,
        status: 0
    )
    render json: st.sanitize_attributes, status: :ok
  rescue => e
    render json: {error: e}, status: :ok

  end

  def show

    case params[:type]
      when 'store'
        render json: StoreTransaction.where(store: current_user.stores.find(params[:store_id])).map(&:sanitize_attributes), status: :ok
      else
        render json: StoreTransaction.where(requester_id: current_user.id).map(&:sanitize_attributes), status: :ok
    end
  rescue => e
    render json: {error: e}, status: :ok

  end

  def destroy
    StoreTransaction.where(requester_id: current_user.id, id: params[:request_id]).first.destroy!
    params[:type] = 'user'
    show
  rescue => e
    render json: {error: e}, status: :ok

  end

  # Accept / Reject request

  def confirm
    begin
      accept = params[:accept].eql?('true')
      st = StoreTransaction.where(id: params[:request_id], store: current_user.stores.find(params[:store_id])).first
      if accept
        st.status = 1
        st.store.owner = st.requester
        st.store.save!
      else
        st.status = 2
      end
      st.save!
      render json: st.sanitize_attributes, status: :ok
    rescue => e
      render json: {error: e}, status: :ok
    end
  end
end
