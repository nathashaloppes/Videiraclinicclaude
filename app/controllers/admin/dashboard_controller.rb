class Admin::DashboardController < Admin::BaseController
  def index
    clinic = current_user.clinic

    # Reservas confirmadas para hoje
    @todays_bookings = Booking.where(clinic: clinic, status: "confirmed")
      .joins(:availability)
      .where(availabilities: { date: Date.current }).count

    # Saldo de crédito disponível nas carteiras que ENTRA na receita (in_revenue).
    # Exclui crédito promocional e os marcados para não entrar na receita.
    @available_credits = Credit.available.where(clinic: clinic, in_revenue: true)
      .where.not("reason ILIKE ?", "%promocional%")
      .sum(:amount_cents)

    # Receita das reservas CONFIRMADAS no mês, contada uma vez por reserva
    # (turnos = total − insumos). Reservas pagas com crédito também contam (o
    # crédito vira receita ao ser usado). Canceladas/expiradas não entram.
    range = Date.current.beginning_of_month..Date.current.end_of_month
    @monthly_turnos, @monthly_insumos = revenue_split(clinic, range)

    # Total do mês = tudo que entrou na conta: turnos + insumos + créditos.
    @monthly_revenue = @monthly_turnos + @monthly_insumos + @available_credits

    @monthly_series = build_monthly_series(clinic, months: 6)
  end

  private

  def revenue_split(clinic, range)
    groups = confirmed_groups(clinic).select { |g| range.cover?(group_paid_at(g)) }
    # Crédito "fora da receita" usado na reserva é abatido do valor que conta.
    off_books = Credit.where(used_on_booking_group: groups.map(&:id), in_revenue: false)
                      .group(:used_on_booking_group_id).sum(:amount_cents)

    turnos = insumos = 0
    groups.each do |g|
      ins       = extras_cents(g.extras)
      countable = [g.total_cents.to_i - off_books[g.id].to_i, 0].max
      g_insumos = [ins, countable].min   # off-books reduz turnos primeiro
      insumos  += g_insumos
      turnos   += countable - g_insumos
    end
    [turnos, insumos]
  end

  def confirmed_groups(clinic)
    @confirmed_groups ||= BookingGroup.where(clinic: clinic, status: "confirmed").includes(:payments).to_a
  end

  # Mês da receita: data do 1º pagamento confirmado (fallback: criação).
  def group_paid_at(group)
    group.payments.select(&:paid?).filter_map(&:paid_at).min || group.created_at
  end

  def extras_cents(extras)
    Array(extras).sum { |e| e["price_cents"].to_i * e["quantity"].to_i }
  end

  def build_monthly_series(clinic, months:)
    groups = confirmed_groups(clinic)
    today  = Date.current
    (0...months).map { |i| (today << i).beginning_of_month }.reverse.map do |start|
      range = start..start.end_of_month
      cents = groups.sum { |g| range.cover?(group_paid_at(g)) ? g.total_cents.to_i : 0 }
      { month: start, cents: cents }
    end
  end
end
