class Payments::PaymentsController < ApplicationController
  def show
    @payment = policy_scope(Payment)
      .includes(booking_group: [:bookings, :dentist])
      .find(params[:id])
    authorize @payment
  end

  # Página de espera — redireciona para o checkout InfinitePay se ainda pendente
  def pending
    @payment = policy_scope(Payment).find(params[:id])
    authorize @payment, :show?

    if @payment.pending? && @payment.checkout_url.present?
      redirect_to @payment.checkout_url, allow_other_host: true
    end
  end

  # Retorno após pagamento no InfinitePay
  # InfinitePay redireciona para /pagamento/retorno?order_nsu=...&transaction_nsu=...&slug=...
  def return
    group = BookingGroup.find_by(id: params[:order_nsu])
    return redirect_to root_path, alert: "Reserva não encontrada." unless group

    @payment = group.payment
    authorize @payment, :show?

    # Se ainda pendente, consulta diretamente o InfinitePay como fallback (webhook pode demorar)
    if @payment.pending? && params[:transaction_nsu].present? && params[:slug].present?
      result = InfinitePay::PaymentChecker.call(
        order_nsu:       params[:order_nsu],
        transaction_nsu: params[:transaction_nsu],
        slug:            params[:slug]
      )

      if result.success? && result.value["paid"]
        PaymentConfirmer.call_from_webhook(
          "order_nsu"       => params[:order_nsu],
          "transaction_nsu" => params[:transaction_nsu],
          "capture_method"  => "pix",
          "paid_amount"     => result.value["paid_amount"]
        )
        @payment.reload
      end
    end
  end

  def cancel
    @payment = policy_scope(Payment).find(params[:id])
    authorize @payment, :show?

    group = @payment.booking_group
    return redirect_to pagamento_path(@payment), alert: "Pagamento já processado." unless group.pending?

    ActiveRecord::Base.transaction do
      @payment.update!(status: "cancelled")
      group.cancel!
    end

    redirect_to reservas_path, notice: "Reserva cancelada."
  rescue => e
    redirect_to pagamento_path(@payment), alert: "Não foi possível cancelar: #{e.message}"
  end
end
