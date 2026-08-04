class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Fundo da Escola <noreply@fundodaescola.com.br>") }
  layout "mailer"

  # Helper for branded subjects.
  def self.branded_subject(text)
    "[Fundo da Escola] #{text}"
  end
end
