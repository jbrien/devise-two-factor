require 'spec_helper'
require 'active_model'

class TwoFactorAuthenticatableDouble
  include ::ActiveModel::Validations::Callbacks
  extend  ::Devise::Models

  devise :two_factor_authenticatable

  attr_accessor :consumed_timestep

  def save(validate)
    # noop for testing
    true
  end
end

describe ::Devise::Models::TwoFactorAuthenticatable do
  context 'When included in a class' do
    subject { TwoFactorAuthenticatableDouble.new }

    it_behaves_like 'two_factor_authenticatable'
  end
end
