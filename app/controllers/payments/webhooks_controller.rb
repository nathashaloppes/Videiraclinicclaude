class Payments::WebhooksController < ActionController::Base
  protect_from_forgery with: :null_session

  def infinitepay
    payload = JSON.parse(request.body.read)

    # InfinitePay não documenta assinatura HMAC — validamos pelo order_nsu existir no banco.
    # NOTA: confirmar com suporte InfinitePay se há header de assinatura a validar.
    order_nsu = payload["order_nsu"].to_s
    unless BookingGroup.exists?(id: order_nsu)
      Rails.logger.warn("[Webhook InfinitePay] order_nsu desconhecido: #{order_nsu}")
      return head :ok
    end

    # Só processa Pix aprovado (pagamentos via cartão são ignorados — app é Pix only)
    if payload["capture_method"] == "pix" && payload["paid_amount"].to_i > 0
      PaymentConfirmer.call_from_webhook(payload)
    end

    head :ok
  rescue JSON::ParserError
    Rails.logger.error("[Webhook InfinitePay] JSON inválido")
    head :bad_request
  rescue => e
    Rails.logger.error("[Webhook InfinitePay] #{e.class}: #{e.message}")
    head :ok  # sempre 200 para InfinitePay não criar loop de retentativas
  end
end
