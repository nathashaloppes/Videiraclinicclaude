module RecurringShifts
  # Materializa os turnos recorrentes (ShiftTemplate) em Availabilities concretas.
  class Generator
    HORIZON_DAYS = 90

    # Geração diária (job): cria os turnos só para datas NOVAS (após o marcador),
    # preservando exclusões/bloqueios que o admin fez em dias já gerados.
    def self.advance(clinic)
      templates = clinic.shift_templates.active.to_a
      return if templates.empty?

      target_end = Date.current + HORIZON_DAYS
      start_date = [(clinic.shifts_generated_until || Date.yesterday) + 1, Date.current].max
      return if start_date > target_end

      (start_date..target_end).each do |date|
        templates.each { |t| create_availability(clinic, t, date) }
      end

      clinic.update_column(:shifts_generated_until, target_end)
    end

    # Preenche UM template em toda a janela já gerada (ao criar/reativar um modelo),
    # sem mexer nos outros turnos (não reaparecem os que o admin excluiu).
    def self.fill_template(template)
      clinic     = template.clinic
      target_end = [clinic.shifts_generated_until || Date.current, Date.current + HORIZON_DAYS].max
      (Date.current..target_end).each { |date| create_availability(clinic, template, date) }
    end

    def self.create_availability(clinic, template, date)
      return if clinic.availabilities.where(date: date, starts_at: template.starts_at).exists?

      clinic.availabilities.create(
        date:        date,
        starts_at:   template.starts_at,
        ends_at:     template.ends_at,
        price_cents: template.price_cents,
        status:      "available"
      )
    rescue ActiveRecord::RecordNotUnique
      # corrida — outro processo já criou o mesmo turno
    end
  end
end
