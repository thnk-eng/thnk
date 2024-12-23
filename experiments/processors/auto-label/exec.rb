# frozen_string_literal: true

module Slide
  class Executor
    def initialize(script_path)
      @script_path = script_path
      @extension = File.extname(script_path)
    end

    def make_executable
      if File.exist?(@script_path)
        if system("chmod +x #{@script_path}")
          puts "File permissions changed: script is now executable."
          true
        else
          puts "Failed to change file permissions."
          false
        end
      else
        puts "Error: Script file does not exist."
        false
      end
    end

    def execute_script(*args)
      begin
        command = case @extension
                  when ".rb"
                    "ruby #{@script_path} #{args.join(' ')}"
                  when ".py"
                    "python3 #{@script_path} #{args.join(' ')}"
                  else
                    raise "Unsupported script type: #{@extension}"
                  end

        Dir.chdir(File.dirname(@script_path)) do
          system(command)
        end
        puts "Script executed successfully."
      rescue StandardError => e
        puts "Error executing script: #{e.message}"
      end
    end
  end
end

# Example usage:
script_path = 'label_serv2.rb'
executor = Slide::Executor.new(script_path)

if executor.make_executable
  executor.execute_script("arg1", "arg2")  # You can pass arguments to the script
end

# For Python script example
python_script_path = ''
python_executor = Slide::Executor.new(python_script_path)

if python_executor.make_executable
  python_executor.execute_script("arg1", "arg2")  # You can pass arguments to the script
end
