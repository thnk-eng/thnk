# spec/envo/key_manager_spec.rb
require 'rails_helper'

RSpec.describe Envo::KeyManager do
  let(:valid_key) { 'a' * 64 } # 64-character hexadecimal string
  let(:invalid_key) { 'invalid_key' }

  describe '.generate_key' do
    it 'generates a key of the correct length' do
      key = Envo::KeyManager.generate_key
      expect(key).to be_a(String)
      expect(key.length).to eq(64)
    end

    it 'generates a unique key each time' do
      key1 = Envo::KeyManager.generate_key
      key2 = Envo::KeyManager.generate_key
      expect(key1).not_to eq(key2)
    end
  end

  describe '.get_key' do
    context 'when the encryption key is set in credentials' do
      before do
        Rails.application.credentials.envo_encryption_key = valid_key
      end

      it 'retrieves the encryption key' do
        expect(Envo::KeyManager.get_key).to eq(valid_key)
      end
    end

    context 'when the encryption key is not set' do
      before do
        Rails.application.credentials.envo_encryption_key = nil
      end

      it 'raises an Envo::Error' do
        expect { Envo::KeyManager.get_key }.to raise_error(Envo::Error, /Encryption key is not set/)
      end
    end
  end

  describe '.set_key' do
    let(:new_key) { 'b' * 64 }

    it 'sets the encryption key in credentials' do
      expect {
        Envo::KeyManager.set_key(new_key)
      }.to change { Rails.application.credentials.envo_encryption_key }.to(new_key)
    end

    context 'when setting the key fails' do
      before do
        allow(Rails.application.credentials).to receive(:write).and_raise(StandardError, 'Write error')
      end

      it 'raises an Envo::Error' do
        expect { Envo::KeyManager.set_key(new_key) }.to raise_error(Envo::Error, /Failed to set encryption key/)
      end
    end
  end

  describe '.validate_key!' do
    context 'with a valid key' do
      before do
        Rails.application.credentials.envo_encryption_key = valid_key
      end

      it 'does not raise an error' do
        expect { Envo::KeyManager.validate_key! }.not_to raise_error
      end
    end

    context 'with an invalid key' do
      before do
        Rails.application.credentials.envo_encryption_key = invalid_key
      end

      it 'raises an Envo::Error' do
        expect { Envo::KeyManager.validate_key! }.to raise_error(Envo::Error, /Encryption key must be a valid hexadecimal/)
      end
    end
  end

  describe '.rotate_key' do
    let(:new_key) { 'c' * 64 }

    before do
      Rails.application.credentials.envo_encryption_key = valid_key
      Envo::EnvLoader.init(valid_key)
      Envo.set('API_KEY', 'test_api_key')
    end

    it 'rotates the encryption key successfully' do
      expect {
        Envo::KeyManager.rotate_key(new_key)
      }.not_to raise_error

      # Verify that the key has been updated
      expect(Rails.application.credentials.envo_encryption_key).to eq(new_key)

      # Verify that the environment variable can be decrypted with the new key
      decrypted_value = Envo.get('API_KEY')
      expect(decrypted_value).to eq('test_api_key')
    end

    context 'when rotation fails' do
      before do
        allow(Envo::EnvLoader).to receive(:rotate_key).and_raise(StandardError, 'Rotation error')
      end

      it 'raises an Envo::Error and does not update the key' do
        expect { Envo::KeyManager.rotate_key(new_key) }.to raise_error(Envo::Error, /Key rotation failed/)
        expect(Rails.application.credentials.envo_encryption_key).to eq(valid_key)
      end
    end
  end
end
