class Scheduling::CartsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @cart_availabilities = cart_availabilities
  end

  def add
    av = Availability.available.find_by(id: params[:availability_id])

    if av.nil?
      return redirect_back(fallback_location: root_path, alert: "Horário indisponível.")
    end

    cart_ids << av.id unless cart_ids.include?(av.id)
    session[:cart_ids] = cart_ids

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: root_path) }
    end
  end

  def remove
    cart_ids.delete(params[:availability_id])
    session[:cart_ids] = cart_ids

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: carrinho_path) }
    end
  end

  def add_extra
    extra = Extra.active.find_by(id: params[:extra_key])
    if extra
      extras = cart_extras
      extras[extra.id] = extras[extra.id].to_i + 1
      session[:cart_extras] = extras
    end

    @cart_availabilities = cart_availabilities
    respond_to do |format|
      format.turbo_stream { render :extras_update }
      format.html do
        flash[:notice] = "#{extra.name} adicionado ao carrinho." if extra
        redirect_back(fallback_location: carrinho_path)
      end
    end
  end

  def remove_extra
    extras = cart_extras
    key = params[:extra_key].to_s
    if extras[key]
      extras[key] = extras[key].to_i - 1
      extras.delete(key) if extras[key] <= 0
      session[:cart_extras] = extras
    end

    @cart_availabilities = cart_availabilities
    respond_to do |format|
      format.turbo_stream { render :extras_update }
      format.html { redirect_back(fallback_location: carrinho_path) }
    end
  end

  def destroy
    session.delete(:cart_ids)
    session.delete(:cart_extras)
    redirect_back(fallback_location: root_path)
  end

  private

  def cart_ids
    @cart_ids ||= Array(session[:cart_ids])
  end

  def cart_extras
    @cart_extras ||= (session[:cart_extras] || {}).to_h
  end

  def cart_availabilities
    return [] if cart_ids.empty?
    Availability.where(id: cart_ids).includes(:service, :dentist)
      .to_a
      .sort_by { |a| [a.date, a.starts_at.strftime("%H:%M")] }
  end
end
