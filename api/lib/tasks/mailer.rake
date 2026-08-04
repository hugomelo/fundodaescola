namespace :mailer do
  desc "Send a Postmark test email. Usage: rails mailer:test ADDRESS=you@example.com"
  task test: :environment do
    address = ENV["ADDRESS"].to_s.strip
    abort "Set ADDRESS=recipient@example.com" if address.blank?
    abort "POSTMARK_API_TOKEN is not set" if ENV["POSTMARK_API_TOKEN"].to_s.strip.blank?

    UserMailer.with(email: address).test_message.deliver_now
    puts "Test email sent to #{address}"
  end
end
