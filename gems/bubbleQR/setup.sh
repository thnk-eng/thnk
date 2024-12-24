#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables (Customize these as needed)
GEM_NAME="thnk_products"
GEM_DIR="thnk_products"
GEM_VERSION="0.1.0"
AUTHOR_NAME="Your Name"
AUTHOR_EMAIL="your.email@example.com"
GEM_HOME_PAGE="https://github.com/yourusername/thnk_products"
GEM_LICENSE="MIT"

# Function to print messages
print_msg() {
  echo "======================================"
  echo "$1"
  echo "======================================"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for Bundler
if ! command_exists bundle; then
    echo "Bundler could not be found. Please install Bundler with 'gem install bundler' and retry."
    exit 1
fi

# Check for Git
if ! command_exists git; then
    echo "Git could not be found. Please install Git and retry."
    exit 1
fi

# Create the gem scaffold
print_msg "Creating gem scaffold for '$GEM_NAME'"

# Create the gem without executable files, tests, and Git setup
bundle gem "$GEM_NAME" --no-exe --no-test --no-git --quiet

cd "$GEM_NAME"

# Remove unnecessary files (if any were created)
rm -rf bin/ pkg/ test/ spec/ .gitignore

# Initialize Git
git init
git add .
git commit -m "Initial commit for $GEM_NAME gem"

# Update gemspec
print_msg "Configuring the gemspec"

cat > "$GEM_NAME.gemspec" <<EOL
# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "$GEM_NAME"
  spec.version       = ThnkProducts::VERSION
  spec.authors       = ["$AUTHOR_NAME"]
  spec.email         = ["$AUTHOR_EMAIL"]

  spec.summary       = "Thnk Products business logic encapsulated in a gem."
  spec.description   = "A Ruby gem to handle business logic for Thnk products, separating it from the Rails controller."
  spec.homepage      = "$GEM_HOME_PAGE"
  spec.license       = "$GEM_LICENSE"

  spec.files         = Dir["lib/**/*", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "prawn"
  spec.add_dependency "barby"
  spec.add_dependency "rails", ">= 6.0"
  spec.add_dependency "rqrcode"

  spec.add_development_dependency "rspec"
  spec.add_development_dependency "factory_bot"
  spec.add_development_dependency "faker"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake"
end
EOL

# Create lib/thnk_products.rb
print_msg "Creating main gem file"

cat > lib/"$GEM_NAME".rb <<EOL
require "$GEM_NAME/version"
require "$GEM_NAME/engine"
require "$GEM_NAME/configuration"

module ThnkProducts
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end
end
EOL

# Create lib/thnk_products/version.rb
print_msg "Creating version file"

mkdir -p lib/"$GEM_NAME"

cat > lib/"$GEM_NAME"/version.rb <<EOL
module ThnkProducts
  VERSION = "$GEM_VERSION"
end
EOL

# Create lib/thnk_products/configuration.rb
print_msg "Creating configuration file"

cat > lib/"$GEM_NAME"/configuration.rb <<EOL
module ThnkProducts
  class Configuration
    attr_accessor :default_page_size,
                  :default_label_size,
                  :printer_type,
                  :thermal_printer_settings

    def initialize
      @default_page_size = "LETTER"  # Default page size
      @default_label_size = [1, 1]   # Default label size in inches [width, height]
      @printer_type = :standard      # :standard, :thermal, :sheet, :roll
      @thermal_printer_settings = {
        dpi: 203,                     # Dots per inch for thermal printers
        width: 80,                    # Width in mm
        height: 297                   # Height in mm
      }
    end
  end
end
EOL

# Create lib/thnk_products/engine.rb
print_msg "Creating engine file"

cat > lib/"$GEM_NAME"/engine.rb <<EOL
module ThnkProducts
  class Engine < ::Rails::Engine
    isolate_namespace ThnkProducts

    initializer "thnk_products.mime_types" do
      Mime::Type.register "application/pdf", :pdf unless Mime::Type.lookup_by_extension(:pdf)
    end
  end
end
EOL

# Create service classes directory
print_msg "Creating service classes"

mkdir -p lib/"$GEM_NAME"/products

# Create IndexService
print_msg "Creating IndexService"

cat > lib/"$GEM_NAME"/products/index_service.rb <<'EOL'
module ThnkProducts
  module Products
    class IndexService
      def initialize(params)
        @params = params
      end

      def call
        products = ThnkProduct.includes(:thnk_variants).order(:title)
        products = apply_query(products)
        products = apply_filters(products)
        products = products.distinct.page(@params[:page]).per(10)

        filters = {
          categories: ThnkProduct.distinct.pluck(:product_category).compact,
          vendors: ThnkProduct.distinct.pluck(:vendor).compact,
          product_types: ThnkProduct.distinct.pluck(:product_type).compact
        }

        { products: products, filters: filters }
      end

      private

      def apply_query(products)
        query = @params[:query]
        return products unless query.present?

        products.where(
          'title ILIKE :query OR
           handle ILIKE :query OR
           vendor ILIKE :query OR
           product_category ILIKE :query OR
           product_type ILIKE :query OR
           thnk_variants.variant_sku ILIKE :query',
          query: "%#{query}%"
        ).references(:thnk_variants)
      end

      def apply_filters(products)
        products = products.where(product_category: @params[:category]) if @params[:category].present?
        products = products.where(vendor: @params[:vendor]) if @params[:vendor].present?
        products = products.where(product_type: @params[:type]) if @params[:type].present?
        products = products.where(status: @params[:status]) if @params[:status].present?
        products = products.where(published: @params[:published]) if @params[:published].present?

        if @params[:min_price].present? || @params[:max_price].present?
          products = products.joins(:thnk_variants).where(
            'thnk_variants.variant_price >= ? AND thnk_variants.variant_price <= ?',
            @params[:min_price].presence || 0,
            @params[:max_price].presence || Float::INFINITY
          )
        end

        if @params[:in_stock].present?
          products = products.joins(:thnk_variants)
                             .where('thnk_variants.variant_inventory_quantity > 0')
        end

        products
      end
    end
  end
end
EOL

# Create ShowService
print_msg "Creating ShowService"

cat > lib/"$GEM_NAME"/products/show_service.rb <<'EOL'
module ThnkProducts
  module Products
    class ShowService
      def initialize(product_id)
        @product_id = product_id
      end

      def call
        product = ThnkProduct.find(@product_id)
        variants = product.thnk_variants
        { product: product, variants: variants }
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end
end
EOL

# Create BulkPrintService
print_msg "Creating BulkPrintService"

cat > lib/"$GEM_NAME"/products/bulk_print_service.rb <<'EOL'
module ThnkProducts
  module Products
    class BulkPrintService
      def initialize(params, session)
        @params = params
        @session = session
      end

      def call
        category = @params[:category]
        return { redirect: true, alert: 'Please select a category' } if category.blank?

        products = ThnkProduct.includes(thnk_variants: { qr_code_image_attachment: :blob })
                               .where(product_category: category)
                               .distinct

        layout = initialize_layout

        # Persist settings in session
        persist_layout(layout)

        {
          category: category,
          products: products,
          layout: layout
        }
      end

      private

      def initialize_layout
        {
          column_gap: sanitize_gap(@params[:column_gap] || @session[:column_gap] || 0.15748),
          row_gap: sanitize_gap(@params[:row_gap] || @session[:row_gap] || 0.15748),
          top_margin: sanitize_gap(@params[:top_margin] || @session[:top_margin] || 0.472441),
          bottom_margin: sanitize_gap(@params[:bottom_margin] || @session[:bottom_margin] || 0.433071),
          left_margin: sanitize_gap(@params[:left_margin] || @session[:left_margin] || 0.393701),
          right_margin: sanitize_gap(@params[:right_margin] || @session[:right_margin] || 0.393701),
          label_size: parse_label_size(@params[:label_size] || "1x1"), # "widthxheight"
          page_size: @params[:page_size] || ThnkProducts.configuration.default_page_size
        }
      end

      def parse_label_size(label_size_str)
        width, height = label_size_str.split('x').map(&:to_f)
        [width, height]
      rescue
        [1, 1]
      end

      def persist_layout(layout)
        layout.each do |key, value|
          @session[key] = value
        end
      end

      def sanitize_gap(value)
        Float(value)
      rescue ArgumentError, TypeError
        0.05 # default fallback
      end
    end
  end
end
EOL

# Create PrintService
print_msg "Creating PrintService"

cat > lib/"$GEM_NAME"/products/print_service.rb <<'EOL'
require 'prawn'
require 'prawn/measurement_extensions'

module ThnkProducts
  module Products
    class PrintService
      def initialize(params, session)
        @params = params
        @session = session
      end

      def call
        products = fetch_products
        layout = fetch_layout
        pdf = generate_pdf(products, layout)
        { pdf: pdf }
      end

      private

      def fetch_products
        if @params[:variant_id].present?
          variant = ThnkVariant.find(@params[:variant_id])
          [variant.thnk_product]
        else
          ThnkProduct.includes(thnk_variants: { qr_code_image_attachment: :blob })
                     .where('title ILIKE ?', "%#{@params[:query]}%")
                     .distinct
        end
      end

      def fetch_layout
        {
          column_gap: @session[:column_gap] || 0.15748,
          row_gap: @session[:row_gap] || 0.15748,
          top_margin: @session[:top_margin] || 0.472441,
          bottom_margin: @session[:bottom_margin] || 0.433071,
          left_margin: @session[:left_margin] || 0.393701,
          right_margin: @session[:right_margin] || 0.393701,
          label_size: @session[:label_size] || [1, 1],
          page_size: @session[:page_size] || ThnkProducts.configuration.default_page_size
        }
      end

      def generate_pdf(products, layout)
        case ThnkProducts.configuration.printer_type
        when :thermal
          generate_thermal_pdf(products, layout)
        when :sheet
          generate_sheet_pdf(products, layout)
        when :roll
          generate_roll_pdf(products, layout)
        else
          generate_standard_pdf(products, layout)
        end
      end

      def generate_standard_pdf(products, layout)
        label_width, label_height = layout[:label_size].map { |dim| dim.inches }
        page_size = layout[:page_size]

        pdf = Prawn::Document.new(page_size: page_size, margin: layout.values_at(:top_margin, :right_margin, :bottom_margin, :left_margin).map { |m| m.inches })

        columns = calculate_columns(page_size, layout[:left_margin], layout[:right_margin], label_width, layout[:column_gap].inches)
        rows = calculate_rows(page_size, layout[:top_margin], layout[:bottom_margin], label_height, layout[:row_gap].inches)

        labels = collect_labels(products, label_width, label_height)

        place_labels(pdf, labels, label_width, label_height, layout, columns, rows)

        pdf
      end

      def generate_sheet_pdf(products, layout)
        label_width, label_height = layout[:label_size].map { |dim| dim.inches }
        page_size = layout[:page_size]

        pdf = Prawn::Document.new(page_size: page_size, margin: layout.values_at(:top_margin, :right_margin, :bottom_margin, :left_margin).map { |m| m.inches })

        columns = calculate_columns(page_size, layout[:left_margin], layout[:right_margin], label_width, layout[:column_gap].inches)
        rows = calculate_rows(page_size, layout[:top_margin], layout[:bottom_margin], label_height, layout[:row_gap].inches)

        labels = collect_labels(products, label_width, label_height)

        place_labels(pdf, labels, label_width, label_height, layout, columns, rows)

        pdf
      end

      def generate_roll_pdf(products, layout)
        # For rolls, the page is continuous. We'll simulate this by setting a large height.
        label_width_mm, label_height_mm = layout[:label_size].map { |dim| dim * 25.4 } # Convert inches to mm
        page_size = [layout[:thermal_printer_settings][:width].mm, layout[:thermal_printer_settings][:height].mm].freeze # Example size

        pdf = Prawn::Document.new(page_size: page_size, margin: [layout[:top_margin], layout[:right_margin], layout[:bottom_margin], layout[:left_margin]].map { |m| m.inches }, page_layout: :portrait)

        columns = calculate_columns_thermal(layout[:thermal_printer_settings][:width].mm, layout[:left_margin], layout[:right_margin], label_width_mm, layout[:column_gap].inches * 25.4)
        rows = calculate_rows_thermal(layout[:thermal_printer_settings][:height].mm, layout[:top_margin], layout[:bottom_margin], label_height_mm, layout[:row_gap].inches * 25.4)

        labels = collect_labels(products, label_width_mm / 25.4, label_height_mm / 25.4) # Convert back to inches for consistency

        place_labels(pdf, labels, label_width_mm / 25.4, label_height_mm / 25.4, layout, columns, rows, thermal: true)

        pdf
      end

      def generate_thermal_pdf(products, layout)
        label_width_mm, label_height_mm = layout[:label_size].map { |dim| dim * 25.4 } # Convert inches to mm

        pdf = Prawn::Document.new(page_size: [layout[:thermal_printer_settings][:width].mm, layout[:thermal_printer_settings][:height].mm], margin: [layout[:top_margin], layout[:right_margin], layout[:bottom_margin], layout[:left_margin]].map { |m| m.inches })

        # Calculate columns and rows based on thermal settings
        columns = calculate_columns_thermal(layout[:thermal_printer_settings][:width].mm, layout[:left_margin], layout[:right_margin], label_width_mm, layout[:column_gap].inches * 25.4)
        rows = calculate_rows_thermal(layout[:thermal_printer_settings][:height].mm, layout[:top_margin], layout[:bottom_margin], label_height_mm, layout[:row_gap].inches * 25.4)

        labels = collect_labels(products, label_width_mm / 25.4, label_height_mm / 25.4) # Convert back to inches

        place_labels(pdf, labels, label_width_mm / 25.4, label_height_mm / 25.4, layout, columns, rows, thermal: true)

        pdf
      end

      def calculate_columns(page_size, left_margin, right_margin, label_width, column_gap)
        page_dimensions = Prawn::Document::PageGeometry.dimensions(page_size)
        usable_width = page_dimensions[0] - left_margin - right_margin
        ((usable_width + column_gap) / (label_width + column_gap)).floor
      end

      def calculate_rows(page_size, top_margin, bottom_margin, label_height, row_gap)
        page_dimensions = Prawn::Document::PageGeometry.dimensions(page_size)
        usable_height = page_dimensions[1] - top_margin - bottom_margin
        ((usable_height + row_gap) / (label_height + row_gap)).floor
      end

      def calculate_columns_thermal(width_mm, left_margin, right_margin, label_width_mm, column_gap_mm)
        usable_width = width_mm - (left_margin * 25.4) - (right_margin * 25.4)
        ((usable_width + column_gap_mm) / (label_width_mm + column_gap_mm)).floor
      end

      def calculate_rows_thermal(height_mm, top_margin, bottom_margin, label_height_mm, row_gap_mm)
        usable_height = height_mm - (top_margin * 25.4) - (bottom_margin * 25.4)
        ((usable_height + row_gap_mm) / (label_height_mm + row_gap_mm)).floor
      end

      def collect_labels(products, label_width, label_height)
        labels = []
        products.each do |product|
          product.thnk_variants.each do |variant|
            next unless variant.qr_code_image.attached?

            temp_file = Tempfile.new(['qr_code', '.png'])
            begin
              temp_file.binmode
              temp_file.write(variant.qr_code_image.download)
              temp_file.rewind

              price = ActionController::Base.helpers.number_to_currency(variant.variant_price, unit: '$')
              stock_quantity = variant.variant_inventory_quantity

              stock_quantity.times do
                labels << { qr_path: temp_file.path, price: price }
              end
            ensure
              temp_file.close
            end
          end
        end
        labels
      end

      def place_labels(pdf, labels, label_width, label_height, layout, columns, rows, thermal: false)
        labels.each_with_index do |label, index|
          column = index % columns
          row = (index / columns) % rows

          if index > 0 && row == 0
            pdf.start_new_page
          end

          x_position = column * (label_width.inches + layout[:column_gap].inches)
          y_position = pdf.bounds.top - row * (label_height.inches + layout[:row_gap].inches)

          pdf.bounding_box([x_position, y_position], width: label_width.inches, height: label_height.inches) do
            if File.exist?(label[:qr_path])
              pdf.image label[:qr_path], position: :center, fit: [label_width.inches * 0.8, label_height.inches * 0.6]
            else
              pdf.fill_color "FF0000"
              pdf.text "QR Code Missing", align: :center, valign: :center
              pdf.fill_color "000000"
            end

            pdf.move_down 10
            pdf.text label[:price], size: 10, align: :center
          end
        end
      ensure
        cleanup_labels(labels)
      end

      def cleanup_labels(labels)
        labels&.each do |label|
          File.delete(label[:qr_path]) if label[:qr_path] && File.exist?(label[:qr_path])
        end
      end
    end
  end
end
EOL

# Create SingleLabelPrintService
print_msg "Creating SingleLabelPrintService"

cat > lib/"$GEM_NAME"/products/single_label_print_service.rb <<'EOL'
module ThnkProducts
  module Products
    class SingleLabelPrintService
      def initialize(variant_id)
        @variant_id = variant_id
      end

      def call
        variant = ThnkVariant.find(@variant_id)
        product = variant.thnk_product
        pdf = generate_pdf(variant, product)
        { pdf: pdf }
      rescue ActiveRecord::RecordNotFound
        nil
      end

      private

      def generate_pdf(variant, product)
        pdf = Prawn::Document.new(page_size: :letter, margin: [40, 40, 40, 40])

        if variant.qr_code_image.attached?
          temp_file = Tempfile.new(['qr_code', '.png'])
          begin
            temp_file.binmode
            temp_file.write(variant.qr_code_image.download)
            temp_file.rewind
            pdf.image temp_file.path, fit: [450, 450], position: :center
          ensure
            temp_file.close
            temp_file.unlink
          end
        else
          pdf.text "No QR Code Available", align: :center, size: 16
        end

        pdf.move_down 10
        pdf.text "SKU: #{variant.variant_sku}", size: 12, align: :center
        pdf.text ActionController::Base.helpers.number_to_currency(variant.variant_price, unit: '$'), size: 16, align: :center

        pdf
      end
    end
  end
end
EOL

# Create QrCodeService
print_msg "Creating QrCodeService"

cat > lib/"$GEM_NAME"/products/qr_code_service.rb <<'EOL'
module ThnkProducts
  module Products
    class QrCodeService
      def initialize(variant_id)
        @variant_id = variant_id
      end

      def call
        variant = ThnkVariant.find(@variant_id)
        generate_qr_code(variant)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      private

      def generate_qr_code(variant)
        # Implement QR code generation logic here
        # Example using RQRCode:
        qr = RQRCode::QRCode.new(variant.variant_sku)
        png = qr.as_png(size: 240)
        variant.qr_code_image.attach(io: StringIO.new(png.to_s), filename: "qr_code_#{variant.id}.png", content_type: 'image/png')
      end
    end
  end
end
EOL

# Create BarcodeService
print_msg "Creating BarcodeService"

cat > lib/"$GEM_NAME"/products/barcode_service.rb <<'EOL'
module ThnkProducts
  module Products
    class BarcodeService
      def initialize(variant_id)
        @variant_id = variant_id
      end

      def call
        variant = ThnkVariant.find(@variant_id)
        generate_barcode(variant)
      rescue ActiveRecord::RecordNotFound
        nil
      end

      private

      def generate_barcode(variant)
        if variant.variant_barcode.present?
          barcode = Barby::Code128B.new(variant.variant_barcode)
          barcode_image = barcode.to_png(xdim: 2)
          variant.barcode_image.attach(io: StringIO.new(barcode_image), filename: "barcode_#{variant.variant_sku}.png", content_type: 'image/png')
        else
          nil
        end
      end
    end
  end
end
EOL

# Create QuickviewService
print_msg "Creating QuickviewService"

cat > lib/"$GEM_NAME"/products/quickview_service.rb <<'EOL'
module ThnkProducts
  module Products
    class QuickviewService
      def initialize(variant_id)
        @variant_id = variant_id
      end

      def call
        variant = ThnkVariant.includes(:thnk_product).find(@variant_id)
        product = variant.thnk_product
        { variant: variant, product: product }
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end
end
EOL

# Commit service classes
git add lib/"$GEM_NAME"/products/
git commit -m "Add all service classes: IndexService, ShowService, BulkPrintService, PrintService, SingleLabelPrintService, QrCodeService, BarcodeService, QuickviewService"

# Integrate the gem into Rails app's Gemfile
print_msg "Integrating the gem into the Rails application"

cd ..

# Check if Gemfile already contains the gem
if grep -q "gem '$GEM_NAME'" Gemfile; then
  echo "Gem '$GEM_NAME' already exists in the Gemfile. Skipping addition."
else
  echo "gem '$GEM_NAME', path: './$GEM_DIR'" >> Gemfile
  echo "Added '$GEM_NAME' to Gemfile."
fi

# Run bundle install
print_msg "Running bundle install"

bundle install

# Create the initializer
print_msg "Creating initializer for $GEM_NAME"

mkdir -p config/initializers

cat > config/initializers/"$GEM_NAME".rb <<EOL
ThnkProducts.configure do |config|
  config.default_page_size = "A4" # or "LETTER", "A3", etc.
  config.default_label_size = [1, 1] # [width, height] in inches
  config.printer_type = :standard # options: :standard, :thermal, :sheet, :roll

  config.thermal_printer_settings = {
    dpi: 203,
    width: 80,  # Width in mm
    height: 297 # Height in mm
  }
end
EOL

git add config/initializers/"$GEM_NAME".rb
git commit -m "Add initializer for $GEM_NAME"

# Refactor the Controller
print_msg "Refactoring Thnk::ProductsController to use the gem"

# Backup the original controller
CONTROLLER_PATH="app/controllers/thnk/products_controller.rb"
BACKUP_PATH="app/controllers/thnk/products_controller_backup.rb"

if [ -f "$CONTROLLER_PATH" ]; then
  cp "$CONTROLLER_PATH" "$BACKUP_PATH"
  echo "Backup of original controller created at $BACKUP_PATH"
else
  echo "Controller $CONTROLLER_PATH does not exist. Exiting."
  exit 1
fi

# Create the new controller content
cat > "$CONTROLLER_PATH" <<'EOL'
module Thnk
  class ProductsController < ApplicationController
    before_action :set_product, only: [:show, :single_print, :print_qr_code, :print_barcode, :quickview]

    # GET /thnk/products
    def index
      service = ThnkProducts::Products::IndexService.new(params)
      result = service.call

      @products = result[:products]
      @filters = result[:filters]

      respond_to do |format|
        format.html
        format.json { render json: @products.as_json(include: :thnk_variants) }
      end
    end

    # GET /thnk/products/:id
    def show
      service = ThnkProducts::Products::ShowService.new(params[:id])
      result = service.call

      if result
        @product = result[:product]
        @variants = result[:variants]

        respond_to do |format|
          format.html { render partial: 'product_details', locals: { product: @product, variants: @variants } }
          format.json { render json: { error: 'Not Found' }, status: :not_found }
        end
      else
        respond_to do |format|
          format.html { redirect_to thnk_products_path, alert: "Product not found." }
          format.json { render json: { error: 'Product not found' }, status: :not_found }
        end
      end
    end

    # GET /thnk/products/bulk_print
    def bulk_print
      service = ThnkProducts::Products::BulkPrintService.new(params, session)
      result = service.call

      if result[:redirect]
        redirect_to thnk_products_path, alert: result[:alert]
      else
        @category = result[:category]
        @products = result[:products]
        @layout = result[:layout]

        respond_to do |format|
          format.html { render :bulk_print }
        end
      end
    end

    # GET /thnk/products/print
    def print
      service = ThnkProducts::Products::PrintService.new(params, session)
      result = service.call

      respond_to do |format|
        format.pdf { send_data result[:pdf].render, filename: "labels_stock_based.pdf", type: 'application/pdf', disposition: 'inline' }
        format.html { redirect_to thnk_products_path, notice: "Print job completed." }
      end
    end

    # GET /thnk/products/single_label_print/:variant_id
    def single_label_print
      service = ThnkProducts::Products::SingleLabelPrintService.new(params[:variant_id])
      result = service.call

      if result
        pdf = result[:pdf]
        respond_to do |format|
          format.pdf { send_data pdf.render, filename: "single_label.pdf", type: 'application/pdf', disposition: 'inline' }
          format.html { redirect_to thnk_product_path(@product), notice: "Single label print completed." }
        end
      else
        redirect_to thnk_products_path, alert: "Variant not found."
      end
    end

    # GET /thnk/products/print_qr_code/:variant_id
    def print_qr_code
      service = ThnkProducts::Products::QrCodeService.new(params[:variant_id])
      result = service.call

      if result
        variant = result[:variant]
        pdf = Prawn::Document.new
        pdf.image variant.qr_code_image.path, fit: [200, 200]
        respond_to do |format|
          format.pdf { send_data pdf.render, filename: "qr_code_#{variant.variant_sku}.pdf", type: 'application/pdf', disposition: 'inline' }
          format.html { redirect_to thnk_product_path(@product), notice: "QR Code printed successfully." }
        end
      else
        redirect_to thnk_products_path, alert: "Variant not found."
      end
    end

    # GET /thnk/products/print_barcode/:variant_id
    def print_barcode
      service = ThnkProducts::Products::BarcodeService.new(params[:variant_id])
      result = service.call

      if result
        variant = ThnkVariant.find(params[:variant_id])
        pdf = Prawn::Document.new
        pdf.image variant.barcode_image.path, fit: [200, 100]
        respond_to do |format|
          format.pdf { send_data pdf.render, filename: "barcode_#{variant.variant_sku}.pdf", type: 'application/pdf', disposition: 'inline' }
          format.html { redirect_to thnk_product_path(@product), notice: "Barcode printed successfully." }
        end
      else
        redirect_to thnk_products_path, alert: "Variant not found or barcode missing."
      end
    end

    # GET /thnk/products/quickview/:variant_id
    def quickview
      service = ThnkProducts::Products::QuickviewService.new(params[:variant_id])
      result = service.call

      if result
        @variant = result[:variant]
        @product = result[:product]

        respond_to do |format|
          format.html { render partial: 'quickview', locals: { variant: @variant, product: @product } }
          format.json { render json: { variant: @variant, product: @product } }
        end
      else
        respond_to do |format|
          format.html { redirect_to thnk_products_path, alert: "Variant not found." }
          format.json { render json: { error: 'Variant not found' }, status: :not_found }
        end
      end
    end

    private

    def set_product
      service = ThnkProducts::Products::ShowService.new(params[:id])
      result = service.call

      if result
        @product = result[:product]
      else
        redirect_to thnk_products_path, alert: "Product not found."
      end
    end
  end
end
EOL

# Commit the new controller
git add "$CONTROLLER_PATH"
git commit -m "Refactor ProductsController to use $GEM_NAME gem"

print_msg "Setup completed successfully!"

echo "======================================"
echo "ThnkProducts gem has been set up successfully."
echo "A backup of the original controller is located at $BACKUP_PATH"
echo "Please review the changes and test your application."
echo "======================================"
