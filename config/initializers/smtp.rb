if ENV["ACTION_MAILER_SMTP_ADDRESS"]
  ActionMailer::Base.smtp_settings = {
    address:        ENV["ACTION_MAILER_SMTP_ADDRESS"],
    port:           ENV["ACTION_MAILER_SMTP_PORT"],
    domain:         ENV["ACTION_MAILER_SMTP_DOMAIN"],
    authentication: ENV["ACTION_MAILER_SMTP_AUTH"],
    user_name:      ENV["ACTION_MAILER_SMTP_USERNAME"],
    password:       ENV["ACTION_MAILER_SMTP_PASSWORD"]
  }
else
  ActionMailer::Base.smtp_settings = {
    authentication:       'plain',
    enable_starttls_auto: false,
    openssl_verify_mode:  'none'
  }
end
