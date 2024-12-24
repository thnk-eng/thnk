# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2024_10_31_035623) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "calypso_batch_analyses", force: :cascade do |t|
    t.string "input_file_uri"
    t.string "output_uri_prefix"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "calypso_product_images", force: :cascade do |t|
    t.integer "product_id"
    t.string "gcs_uri"
    t.string "catalog_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "calypso_product_recognition_indices", force: :cascade do |t|
    t.string "name"
    t.string "catalog_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "calypso_product_sets", force: :cascade do |t|
    t.string "name"
    t.string "catalog_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "calypso_products", force: :cascade do |t|
    t.string "name"
    t.string "gtin"
    t.string "catalog_id"
    t.text "description"
    t.decimal "price"
    t.bigint "calypso_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calypso_user_id"], name: "index_calypso_products_on_calypso_user_id"
  end

  create_table "calypso_users", force: :cascade do |t|
    t.string "name"
    t.string "access_token"
    t.string "project_id"
    t.string "api_base_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "calypso_products", "calypso_users"
end
