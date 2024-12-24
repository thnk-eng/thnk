# app/services/calypso/toolchain.rb
require 'yaml'

module Calypso
  module ApiCalls
    class Toolchain
      def self.process_message(message, context)
        page = context['page']

        case page
          when 'product_catalog'
            handle_product_catalog_message(message, context)
          when 'inventory'
            handle_inventory_message(message, context)
          else
            generic_response(message, context)
        end
      end

      def self.generate_suggestions(context)
        page = context['page']

        case page
          when 'product_catalog'
            "You can create a new product by typing 'create product' or list all products by typing 'list products'."
          when 'inventory'
            "You can check inventory by typing 'check inventory <product_id>' or forecast inventory by typing 'forecast inventory <product_id>'."
          else
            "How can I assist you today?"
        end
      end

      def self.handle_product_catalog_message(message, context)
        if message.downcase.include?('create product')
          "Please upload the product image to proceed with product creation."
        elsif message.downcase.include?('update product')
          "Please provide the Product ID and the details you want to update."
        elsif message.downcase.include?('list products')
          products = Calypso::ApiCalls::Products::ListProducts.call(context['user_id'])
          if products.is_a?(Array)
            formatted_products = format_products(products)
            "Here are the products in your catalog:\n#{formatted_products}"
          else
            "Failed to retrieve products: #{products[:message]}"
          end
        else
          "How can I assist you with the product catalog?"
        end
      end

      def self.handle_inventory_message(message, context)
        if message.downcase.include?('check inventory')
          product_id = extract_product_id(message)
          if product_id
            inventory = Calypso::ApiCalls::Inventory::GetInventoryById.call(product_id)
            if inventory.is_a?(Integer) || inventory.is_a?(Float)
              "Inventory for Product ID #{product_id}: #{inventory} units available."
            else
              "Failed to retrieve inventory: #{inventory[:message]}"
            end
          else
            "Please provide a valid Product ID."
          end
        elsif message.downcase.include?('forecast inventory')
          product_id = extract_product_id(message)
          if product_id
            forecast = Calypso::ApiCalls::Inventory::ForecastInventory.call(product_id)
            if forecast.is_a?(String)
              "Inventory forecast for Product ID #{product_id}: #{forecast}"
            else
              "Failed to retrieve forecast: #{forecast[:message]}"
            end
          else
            "Please provide a valid Product ID."
          end
        else
          "How can I assist you with inventory management?"
        end
      end

      def self.generic_response(message, context)
        # Integrate GPT-4 Vision or other LLM for more dynamic responses
        # Example placeholder response
        "I'm here to help! Please provide more details about your request."
      end

      def self.extract_product_id(message)
        match = message.match(/product\s*id\s*(\d+)/i)
        match ? match[1] : nil
      end

      def self.format_products(products)
        products.map { |p| "ID: #{p['id']}, Name: #{p['name']}, GTIN: #{p['gtin']}" }.join("\n")
      end

      def self.execute_from_yaml(yaml_path, context)
        yaml_content = YAML.safe_load(File.read(yaml_path))
        tool_config = yaml_content['tool']
        tool_name = tool_config['name']

        case tool_name
          when 'create_product_from_image'
            execute_create_product_from_image(tool_config['parameters'], context)
          when 'update_product'
            execute_update_product(tool_config['parameters'], context)
          else
            "Tool #{tool_name} is not supported."
        end
      end

    private

      def self.execute_create_product_from_image(params_config, context)
        missing_params = params_config['required'].reject { |param| context[param.to_s].present? }
        unless missing_params.empty?
          return "Missing required parameters: #{missing_params.join(', ')}"
        end

        user = User.find(context['user_id'])
        product_name = context['product_name']
        gtin = context['gtin']
        catalog_id = context['catalog_id']
        product_image = context['product_image']

        # Handle the product_image if needed (e.g., upload to storage)

        # Create the product via API call
        response = Calypso::ApiCalls::Products::CreateProduct.call(
          user,
          product_name: product_name,
          gtin: gtin,
          catalog_id: catalog_id
        )

        handle_tool_response(response)
      end

      def self.handle_tool_response(response)
        if response[:error]
          "API Call Error: #{response[:message]}"
        else
          "Product created successfully: ID #{response['id']}, Name #{response['name']}."
        end
      end
    end
  end
end
