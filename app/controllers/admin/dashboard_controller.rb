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

    # Receita = valor de face das reservas CONFIRMADAS, contado uma vez por
    # reserva (não por pagamento). Evita contagem dupla com crédito/recarga e
    # ciclos de cancelar-reservar. Crédito não é dinheiro novo: a reserva paga
    # com crédito conta no seu valor uma única vez.
    range = Date.current.beginning_of_month..Date.current.end_of_month
    @monthly_turnos, @monthly_insumos = revenue_split(clinic, range)
    @monthly_revenue = @monthly_turnos + @monthly_insumos

    @monthly_series = build_monthly_series(clinic, months: 6)
  end

  private

  # Soma o valor das reservas confirmadas cujo pagamento foi confirmado no
  # período, separando turnos (total − insumos) de insumos.
  def revenue_split(clinic, range)
    turnos = insumos = 0
    confirmed_groups(clinic).each do |g|
      next unless range.cover?(group_paid_at(g))

      ins = extras_cents(g.extras)
      turnos  += [g.total_cents.to_i - ins, 0].max
      insumos += ins
    end
    [turnos, insumos]
  end

  def confirmed_groups(clinic)
    BookingGroup.where(clinic: clinic, status: "confirmed").includes(:payments)
  end

  # Quando a reserva entrou (mês da receita): data do 1º pagamento confirmado,
  # com fallback para a criação da reserva (ex.: reserva manual do admin).
  def group_paid_at(group)
    group.payments.select(&:paid?).filter_map(&:paid_at).min || group.created_at
  end

  def extras_cents(extras)
    Array(extras).sum { |e| e["price_cents"].to_i * e["quantity"].to_i }
  end

  def build_monthly_series(clinic, months:)
    groups = confirmed_groups(clinic).to_a
    today  = Date.current
    (0...months).map { |i| (today << i).beginning_of_month }.reverse.map do |start|
      range = start..start.end_of_month
      cents = groups.sum { |g| range.cover?(group_paid_at(g)) ? g.total_cents.to_i : 0 }
      { month: start, cents: cents }
    end
  end
end
