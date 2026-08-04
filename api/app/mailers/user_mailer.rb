# Transactional emails to platform users (parents / admins).
#
# Prefer deliver_later so request threads aren't blocked on Postmark:
#   UserMailer.with(user: user).welcome.deliver_later
class UserMailer < ApplicationMailer
  # Smoke-test / connectivity check — used by `rails mailer:test`.
  def test_message
    @email = params.fetch(:email)
    mail(
      to: @email,
      subject: self.class.branded_subject("E-mail de teste"),
      message_stream: "outbound"
    )
  end

  def welcome
    @user = params.fetch(:user)
    mail(
      to: @user.email,
      subject: self.class.branded_subject("Bem-vindo(a)"),
      message_stream: "outbound"
    )
  end

  def password_reset
    @user = params.fetch(:user)
    token = params.fetch(:token)
    @reset_url = frontend_reset_url(token)
    @expires_in = "2 horas"
    mail(
      to: @user.email,
      subject: self.class.branded_subject("Redefinir senha"),
      message_stream: "outbound"
    )
  end

  private

  def frontend_reset_url(token)
    host = ENV.fetch("APP_HOST", "fundodaescola.com.br")
    scheme = host.include?("localhost") ? "http" : "https"
    "#{scheme}://#{host}/#/redefinir-senha?token=#{CGI.escape(token)}"
  end
end
