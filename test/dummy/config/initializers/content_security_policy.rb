# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# The dummy application uses a strict Content Security Policy on purpose. A host
# application with such a policy shows how the engine behaves: the engine must
# put a nonce on its own inline style and script, otherwise the browser blocks
# them.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https
  end

  # A nonce for each request. The suggestion of Rails, `request.session.id.to_s`,
  # gives an empty text when the request has no session yet. The browser then
  # refuses the whole nonce source and blocks the inline style and script.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
