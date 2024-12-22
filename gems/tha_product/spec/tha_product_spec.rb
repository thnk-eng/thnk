# frozen_string_literal: true

RSpec.describe ThaProduct do
  it "has a version number" do
    expect(ThaProduct::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
