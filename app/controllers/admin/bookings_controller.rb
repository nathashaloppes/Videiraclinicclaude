class Admin::BookingsController < Admin::BaseController
  before_action :set_booking_group, only: [:show, :cancel]

  def index
    scope = policy_scope(BookingGroup)
      .includes(:dentist, :bookings, :payment)
      .order(created_at: :desc)

    scope = scope.where(status: params[:status]) if params[:status].present?
    if params[:date].present?
      scope = scope.joins(bookings: :availability)
                   .where(availabilities: { date: Date.parse(params[:date]) })
    end

    @pagy, @booking_groups = pagy(scope)
  end

  def show
    @versions = @booking_group.versions + @booking_group.bookings.flat_map(&:versions)
    @versions.sort_by!(&:created_at).reverse!
  end

  def create
    availability = current_clinic.availabilities.find(params[:availability_id])
    dentist      = User.dentists.where(clinic: current_clinic).find(params[:dentist_id])

    result = AdminBookingCreator.call(availability: availability, dentist: dentist)

    if result.success?
      redirect_to admin_booking_path(result.value), notice: "Reserva criada com sucesso."
    else
      redirect_to admin_availabilities_path(date: availability.date), alert: result.error
    end
  end

  def cancel
    if @booking_group.cancelled?
      return redirect_to admin_booking_path(@booking_group), alert: "Reserva já cancelada."
    end

    @booking_group.cancel!
    redirect_to admin_booking_path(@booking_group), notice: "Reserva cancelada."
  rescue => e
    redirect_to admin_booking_path(@booking_group), alert: "Erro ao cancelar: #{e.message}"
  end

  private

  def set_booking_group
    @booking_group = policy_scope(BookingGroup).find(params[:id])
  end
end
