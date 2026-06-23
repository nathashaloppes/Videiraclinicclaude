class Admin::DashboardController < Admin::BaseController
  def index
    clinic = current_user.clinic

    # Reservas confirmadas para hoje
    @todays_bookings = Booking.where(clinic: clinic, status: "confirmed")
      .joins(:availability)
      .where(availabilities: { date: Date.current }).count

    # Turnos no carrinho ainda não pagos (grupos com pagamento pendente)
    @pending_payments = Booking.where(clinic: clinic)
      .joins(booking_group: :payment)
      .where(payments: { status: "pending" }).count

    # Receita que entrou na conta no mês (pagamentos confirmados) — em centavos
    range = Date.current.beginning_of_month..Date.current.end_of_month
    @monthly_revenue = Payment.paid.where(clinic: clinic, paid_at: range).sum(:amount_cents)

    # Separa a receita do mês em turnos vs insumos (Videira Shop).
    @monthly_turnos, @monthly_insumos = split_revenue(clinic, range)

    @monthly_series = build_monthly_series(clinic, months: 6)
  end

  private

  # Divide o valor recebido no período entre turnos e insumos.
  # Cada pagamento carrega seus insumos (payment.extras); para pagamentos antigos
  # sem esse dado, usa os insumos do grupo (group.extras). Conta uma vez por grupo
  # e limita ao valor recebido (turnos + insumos = total).
  def split_revenue(clinic, range)
    paid = Payment.paid.where(clinic: clinic, paid_at: range).includes(:booking_group).to_a
    insumos = 0

    paid.group_by(&:booking_group_id).each do |gid, payments|
      received = payments.sum { |p| p.amount_cents.to_i }
      carried  = payments.sum { |p| extras_cents(p.extras) }
      ext = if carried.positive?
        carried
      elsif gid
        extras_cents(payments.first.booking_group&.extras)
      else
        0
      end
      insumos += [ext, received].min
    end

    [@monthly_revenue - insumos, insumos]
  end

  def extras_cents(extras)
    Array(extras).sum { |e| e["price_cents"].to_i * e["quantity"].to_i }
  end

  def build_monthly_series(clinic, months:)
    today = Date.current
    (0...months).map { |i| (today << i).beginning_of_month }.reverse.map do |start|
      cents = Payment.paid.where(clinic: clinic, paid_at: start..start.end_of_month).sum(:amount_cents)
      { month: start, cents: cents }
    end
  end
end
