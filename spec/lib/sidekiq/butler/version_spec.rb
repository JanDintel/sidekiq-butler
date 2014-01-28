require 'spec_helper'

describe Sidekiq::Butler do
  describe 'VERSION' do
    specify { expect(described_class::VERSION).to eql '0.0.1' }
  end
end
