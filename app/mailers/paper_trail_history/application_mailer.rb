# frozen_string_literal: true

module PaperTrailHistory
  # Base mailer class for PaperTrailHistory email notifications
  class ApplicationMailer < ActionMailer::Base
    default from: 'from@example.com'
    layout 'mailer'
  end
end
