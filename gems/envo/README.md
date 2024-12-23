# Envo

Envo is a secure environment variable management gem for Rails applications that provides encrypted storage and handling of sensitive configuration values. It extends the functionality of traditional `.env` files by adding encryption, type preservation, and seamless Rails integration.

## Features

- AES-256-GCM encryption for environment variables
- Type preservation for Ruby objects (strings, numbers, arrays, hashes, etc.)
- Secure key rotation capabilities
- Support for both plain and encrypted `.env` files
- Thread-safe operations
- Rails integration with automatic initialization
- YAML serialization for complex data types

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'envo'
```

And then execute:

```bash
$ bundle install
```

### Setup

1. Generate an encryption key:

```ruby
key = Envo::KeyManager.generate_key
```

2. Add the key to your Rails credentials:

```bash
rails credentials:edit
```

Add the following line:

```yaml
envo_encryption_key: your_generated_key_here
```

## Usage

### Basic Usage

```ruby
# Set an encrypted environment variable
Envo.set('API_KEY', 'secret_api_key')

# Get a decrypted environment variable
api_key = Envo.get('API_KEY')
```

### Using .env Files

Create a `.env` file in your Rails root directory:

```env
DATABASE_URL=postgresql://localhost/myapp
API_KEY=secret_key
MAX_CONNECTIONS=5
FEATURE_FLAGS={"enabled": true, "debug": false}
ALLOWED_HOSTS=["localhost", "example.com"]
```

Envo will automatically load and encrypt these variables during Rails initialization.

### Type Preservation

Envo preserves Ruby data types when storing and retrieving values:

```ruby
# Numbers
Envo.set('MAX_CONNECTIONS', 42)
max = Envo.get('MAX_CONNECTIONS') # Returns Integer: 42

# Arrays
Envo.set('ALLOWED_HOSTS', ['localhost', 'example.com'])
hosts = Envo.get('ALLOWED_HOSTS') # Returns Array: ['localhost', 'example.com']

# Hashes
Envo.set('CONFIG', { api_version: 'v1', timeout: 30 })
config = Envo.get('CONFIG') # Returns Hash: { api_version: 'v1', timeout: 30 }

# Booleans
Envo.set('DEBUG_MODE', true)
debug = Envo.get('DEBUG_MODE') # Returns Boolean: true
```

### Key Rotation

To rotate your encryption key:

```ruby
# Generate a new key
new_key = Envo::KeyManager.generate_key

# Rotate to the new key
Envo::KeyManager.rotate_key(new_key)
```

The rotation process will:
1. Re-encrypt all existing environment variables with the new key
2. Update the key in Rails credentials
3. Ensure all operations continue seamlessly

### Rails Integration

Envo automatically initializes with Rails and loads environment variables from:
- `.env.{environment}` (e.g., `.env.development`, `.env.production`)
- Falls back to `.env` if environment-specific file doesn't exist

### Security Considerations

- Encryption keys must be 64-character hexadecimal strings (32 bytes)
- Uses AES-256-GCM for encryption with authenticated encryption
- Includes IV (Initialization Vector) and authentication tag for each value
- Thread-safe operations for concurrent access
- Secure key rotation with atomic updates

### Development Environment

```bash
# Run tests
bundle exec rspec

# Run an interactive console
bin/console
```



## Advanced Usage

```ruby
# Set an encrypted environment variable
Envo.set('API_KEY', 'secret_api_key')

# Get a decrypted environment variable
api_key = Envo.get('API_KEY')

# Check if a variable exists
api_key = Envo.get('API_KEY') # Returns nil if not set
```

### Using .env Files

Create a `.env` file in your Rails root directory:

```env
# Simple string values
DATABASE_URL=postgresql://localhost/myapp
API_KEY=secret_key

# Numeric values
MAX_CONNECTIONS=5
TIMEOUT=30.5

# Boolean values
DEBUG_MODE=true
CACHE_ENABLED=false

# JSON-formatted complex data
FEATURE_FLAGS={"enabled": true, "debug": false}
ALLOWED_HOSTS=["localhost", "example.com"]

# Multiline strings
SSH_KEY="-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEA14ThF...
...
-----END RSA PRIVATE KEY-----"

# Quoted strings with special characters
MESSAGE="Hello, World! This has spaces"
PATH_WITH_SPACES="C:\Program Files\My App"
```

### Type Handling

Envo handles various Ruby data types:

```ruby
# Nested data structures
Envo.set('APP_CONFIG', {
  database: {
    host: 'localhost',
    ports: [5432, 6379],
    options: { timeout: 30, retry: true }
  },
  features: ['auth', 'api', 'webhooks'],
  limits: {
    max_connections: 100,
    rate_limit: 1000.5
  }
})

# Date/Time objects
Envo.set('LAUNCH_DATE', Date.new(2024, 1, 1))
Envo.set('MAINTENANCE_WINDOW', Time.new(2024, 1, 1, 0, 0, 0))

# Symbols (converted to strings during storage)
Envo.set('STATUS', :active)

# Arrays of mixed types
Envo.set('MIXED_ARRAY', [1, "two", { three: 3 }, [4, 5]])
```

### Environment-Specific Configuration

```ruby
# config/environments/development.rb
Envo.load_dotenv('.env.development')

# config/environments/production.rb
Envo.load_dotenv('.env.production')

# Load multiple environment files with overrides
Envo.load_dotenv('.env')                 # Base configuration
Envo.load_dotenv('.env.local')           # Local overrides
Envo.load_dotenv(".env.#{Rails.env}")    # Environment-specific
```

### Error Handling

```ruby
begin
  Envo.set('API_KEY', secret_key)
rescue Envo::Error => e
  Rails.logger.error("Failed to set API key: #{e.message}")
  # Handle error appropriately
end

# Validation errors
begin
  Envo::KeyManager.validate_key!
rescue Envo::Error => e
  Rails.logger.error("Invalid encryption key: #{e.message}")
end

# Decryption errors
begin
  value = Envo.get('CORRUPTED_KEY')
rescue Envo::Error => e
  Rails.logger.error("Decryption failed: #{e.message}")
end
```

### Key Rotation Strategies

```ruby
# Basic key rotation
new_key = Envo::KeyManager.generate_key
Envo::KeyManager.rotate_key(new_key)

# Scheduled key rotation in a rake task
namespace :envo do
  desc 'Rotate encryption key'
  task rotate_key: :environment do
    begin
      old_key = Envo::KeyManager.get_key
      new_key = Envo::KeyManager.generate_key
      
      # Backup current state
      backup_vars = ENV.to_h
      
      # Perform rotation
      Envo::KeyManager.rotate_key(new_key)
      
      puts "Key rotation successful"
    rescue Envo::Error => e
      # Restore backup if rotation fails
      ENV.clear
      ENV.update(backup_vars)
      
      puts "Key rotation failed: #{e.message}"
      exit 1
    end
  end
end
```

### Rails Integration Examples

```ruby
# config/initializers/envo.rb
Rails.application.config.before_configuration do
  # Load environment-specific variables
  env_file = Rails.root.join(".env.#{Rails.env}")
  fallback_file = Rails.root.join('.env')
  
  if File.exist?(env_file)
    Envo.load_dotenv(env_file)
  elsif File.exist?(fallback_file)
    Envo.load_dotenv(fallback_file)
  end
end

# Using with ActiveRecord
class ApplicationRecord < ActiveRecord::Base
  connects_to database: { 
    writing: Envo.get('DATABASE_URL'),
    reading: Envo.get('READONLY_DATABASE_URL')
  }
end

# Using with Action Mailer
class ApplicationMailer < ActionMailer::Base
  default from: Envo.get('MAILER_FROM_ADDRESS')
  
  private
  
  def smtp_settings
    {
      address: Envo.get('SMTP_ADDRESS'),
      port: Envo.get('SMTP_PORT'),
      user_name: Envo.get('SMTP_USERNAME'),
      password: Envo.get('SMTP_PASSWORD')
    }
  end
end
```

### Thread Safety Examples

```ruby
# Concurrent access to environment variables
threads = []
10.times do |i|
  threads << Thread.new do
    Envo.set("THREAD_#{i}", "value_#{i}")
    sleep(rand(0.1..0.5))
    puts Envo.get("THREAD_#{i}")
  end
end
threads.each(&:join)
```

### Testing with Envo

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.before(:suite) do
    # Use a test encryption key
    test_key = Envo::KeyManager.generate_key
    Envo::EnvLoader.init(test_key)
  end
  
  config.before(:each) do
    # Clear any encrypted variables before each test
    ENV.keys.each { |k| ENV.delete(k) if k.start_with?('TEST_') }
  end
end

# In your tests
RSpec.describe "Environment Variables" do
  before do
    Envo.set('TEST_API_KEY', 'test_value')
  end

  it "handles encrypted variables" do
    expect(Envo.get('TEST_API_KEY')).to eq('test_value')
  end
  
  it "handles complex data types" do
    Envo.set('TEST_CONFIG', { api: { version: 'v1' } })
    expect(Envo.get('TEST_CONFIG')).to eq({ api: { version: 'v1' } })
  end
end
```

