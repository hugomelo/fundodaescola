# Shared Action Mailer defaults. Delivery method (Postmark) is set per-environment.
Rails.application.configure do
  config.action_mailer.default_options = {
    from: ENV.fetch("MAIL_FROM", "Fundo da Escola <noreply@fundodaescola.com.br>")
  }
end
