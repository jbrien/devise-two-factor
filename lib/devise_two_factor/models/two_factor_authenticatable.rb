require 'symmetric-encryption'
require 'rotp'

module Devise
  module Models
    module TwoFactorAuthenticatable
      extend ActiveSupport::Concern
      include Devise::Models::DatabaseAuthenticatable

      included do
        attr_encrypted :otp_secret, :random_iv => true if defined?(ActiveRecord)
        validates :encrypted_otp_secret, symmetric_encryption: true, allow_nil: true

        attr_accessor :otp_attempt, :otp_required
      end

      def self.required_fields(klass)
        [:encrypted_otp_secret, :consumed_timestep]
      end

      # This defaults to the model's otp_secret
      # If this hasn't been generated yet, pass a secret as an option
      def validate_and_consume_otp!(code, options = {})
        otp_secret = options[:otp_secret] || self.otp_secret
        return false unless otp_secret.present?

        totp = self.otp(otp_secret)
        return consume_otp! if totp.verify_with_drift(code, self.class.otp_allowed_drift)

        false
      end

      def otp(otp_secret = self.otp_secret)
        ROTP::TOTP.new(otp_secret)
      end

      def current_otp
        otp.at(Time.now)
      end

      # ROTP's TOTP#timecode is private, so we duplicate it here
      def current_otp_timestep
         Time.now.utc.to_i / otp.interval
      end

      def otp_provisioning_uri(account, options = {})
        otp_secret = options[:otp_secret] || self.otp_secret
        ROTP::TOTP.new(otp_secret, options).provisioning_uri(account)
      end

      def clean_up_passwords
        self.otp_attempt = nil
      end

    protected

      # An OTP cannot be used more than once in a given timestep
      # Storing timestep of last valid OTP is sufficient to satisfy this requirement
      def consume_otp!
        if self.consumed_timestep != current_otp_timestep
          self.consumed_timestep = current_otp_timestep
          return save(validate: false)
        end

        false
      end

      module ClassMethods
        Devise::Models.config(self, :otp_secret_length,
                                    :otp_allowed_drift,
                                    :otp_secret_encryption_key)

        def generate_otp_secret(otp_secret_length = self.otp_secret_length)
          ROTP::Base32.random_base32(otp_secret_length)
        end
      end
    end
  end
end
