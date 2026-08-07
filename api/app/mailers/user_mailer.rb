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

  # Sent after bulk import when "enviar convite" is checked.
  # Includes a set-password link and a short explanation of the platform.
  def invite
    @user = params.fetch(:user)
    token = params.fetch(:token)
    @set_password_url = frontend_reset_url(token)
    @expires_in = "24 horas"
    @students = @user.students.includes(:grade).to_a
    @grade_name = @students.map { |s| s.grade&.name }.compact.uniq.first
    mail(
      to: @user.email,
      subject: self.class.branded_subject("Convite para acompanhar o fundo da turma"),
      message_stream: "outbound"
    )
  end

  def password_reset
    @user = params.fetch(:user)
    token = params.fetch(:token)
    @reset_url = frontend_reset_url(token)
    @expires_in = "24 horas"
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

