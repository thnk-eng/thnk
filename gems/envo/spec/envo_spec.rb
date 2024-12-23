# spec/envo_spec.rb
require 'spec_helper'

RSpec.describe Envo::EnvLoader do
  let(:env_content) do
    <<~ENV
      STRING_VAR=simple string
      QUOTED_STRING="quoted string"
      SINGLE_QUOTED='single quoted string'
      MULTILINE="multi
      line
      string"
      NUMBER=42
      BOOLEAN=true
      ARRAY=["item1", "item2"]
      HASH={"key": "value"}
    ENV
  end
  let(:env_file) { 'test.env' }
  let(:encrypted_file) { 'test.env.enc' }
  let(:encryption_key) { 'test_encryption_key' }

  before do
    File.write(env_file, env_content)
    ENV['ENCRYPTED_ENV_KEY'] = encryption_key
  end

  after do
    File.delete(env_file) if File.exist?(env_file)
    File.delete(encrypted_file) if File.exist?(encrypted_file)
    ENV.delete('ENCRYPTED_ENV_KEY')
    %w[STRING_VAR QUOTED_STRING SINGLE_QUOTED MULTILINE NUMBER BOOLEAN ARRAY HASH].each do |key|
      ENV.delete(key)
    end
  end

  describe '.encrypt and .load' do
    it 'encrypts and decrypts various types of variables' do
      Envo::EnvLoader.encrypt(env_file, encrypted_file)
      Envo::EnvLoader.load(encrypted_file)

      expect(ENV['STRING_VAR']).to eq 'simple string'
      expect(ENV['QUOTED_STRING']).to eq 'quoted string'
      expect(ENV['SINGLE_QUOTED']).to eq 'single quoted string'
      expect(ENV['MULTILINE']).to eq "multi\nline\nstring"
      expect(ENV['NUMBER']).to eq '42'
      expect(ENV['BOOLEAN']).to eq 'true'
      expect(ENV['ARRAY']).to eq '["item1", "item2"]'
      expect(ENV['HASH']).to eq '{"key": "value"}'
    end
  end

  describe '.encrypt_value and .decrypt_value' do
    it 'encrypts and decrypts various types of values' do
      test_values = [
        'simple string',
        "multi\nline\nstring",
        42,
        true,
        ['item1', 'item2'],
        { 'key' => 'value' }
      ]

      test_values.each do |value|
        encrypted = Envo::EnvLoader.encrypt_value(value, encryption_key)
        decrypted = Envo::EnvLoader.decrypt_value(encrypted, encryption_key)
        expect(decrypted).to eq value
      end
    end
  end
end