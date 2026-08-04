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
end
