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

ActiveRecord::Schema[8.1].define(version: 2026_08_04_004000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.bigint "grade_id", null: false
    t.string "name", null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["grade_id", "starts_on"], name: "index_events_on_grade_id_and_starts_on"
    t.index ["grade_id"], name: "index_events_on_grade_id"
  end

  create_table "grades", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "BRL", null: false
    t.text "description"
    t.decimal "inflation_rate", precision: 6, scale: 4, default: "0.06", null: false
    t.string "name", null: false
    t.string "school_name"
    t.date "school_year_end"
    t.date "school_year_start"
    t.bigint "target_total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "investment_entries", force: :cascade do |t|
    t.bigint "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "grade_id", null: false
    t.date "month", null: false
    t.string "note"
    t.datetime "updated_at", null: false
    t.index ["grade_id", "month"], name: "index_investment_entries_on_grade_id_and_month", unique: true
    t.index ["grade_id"], name: "index_investment_entries_on_grade_id"
  end

  create_table "monthly_pledges", force: :cascade do |t|
    t.bigint "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "month", null: false
    t.integer "status", default: 0, null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "month"], name: "index_monthly_pledges_on_student_id_and_month", unique: true
    t.index ["student_id"], name: "index_monthly_pledges_on_student_id"
  end

  create_table "payer_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "grade_id", null: false
    t.boolean "maps_to_event", default: false, null: false
    t.string "payer_text", null: false
    t.bigint "student_id"
    t.datetime "updated_at", null: false
    t.index ["grade_id", "payer_text"], name: "index_payer_mappings_on_grade_id_and_payer_text", unique: true
    t.index ["grade_id"], name: "index_payer_mappings_on_grade_id"
    t.index ["student_id"], name: "index_payer_mappings_on_student_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.string "external_ref"
    t.bigint "grade_id", null: false
    t.integer "kind", default: 0, null: false
    t.boolean "needs_review", default: false, null: false
    t.date "paid_on", null: false
    t.string "paid_time"
    t.bigint "payer_mapping_id"
    t.bigint "student_id"
    t.datetime "updated_at", null: false
    t.index ["grade_id", "external_ref"], name: "index_payments_on_grade_id_and_external_ref", unique: true, where: "(external_ref IS NOT NULL)"
    t.index ["grade_id", "needs_review"], name: "index_payments_on_grade_id_and_needs_review"
    t.index ["grade_id"], name: "index_payments_on_grade_id"
    t.index ["paid_on"], name: "index_payments_on_paid_on"
    t.index ["payer_mapping_id"], name: "index_payments_on_payer_mapping_id"
    t.index ["student_id"], name: "index_payments_on_student_id"
  end

  create_table "student_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["student_id"], name: "index_student_accesses_on_student_id"
    t.index ["user_id", "student_id"], name: "index_student_accesses_on_user_id_and_student_id", unique: true
    t.index ["user_id"], name: "index_student_accesses_on_user_id"
  end

  create_table "students", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "display_name"
    t.date "enrolled_from"
    t.date "enrolled_until"
    t.string "full_name", null: false
    t.bigint "grade_id", null: false
    t.datetime "updated_at", null: false
    t.index ["grade_id"], name: "index_students_on_grade_id"
  end

  create_table "trip_cost_entries", force: :cascade do |t|
    t.bigint "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["trip_id", "year"], name: "index_trip_cost_entries_on_trip_id_and_year", unique: true
    t.index ["trip_id"], name: "index_trip_cost_entries_on_trip_id"
  end

  create_table "trips", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "grade_id", null: false
    t.string "level"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "trip_year", null: false
    t.datetime "updated_at", null: false
    t.index ["grade_id", "position"], name: "index_trips_on_grade_id_and_position"
    t.index ["grade_id"], name: "index_trips_on_grade_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "grade_id"
    t.string "name"
    t.string "password_digest", null: false
    t.string "phone"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 2, null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["grade_id"], name: "index_users_on_grade_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "events", "grades"
  add_foreign_key "investment_entries", "grades"
  add_foreign_key "monthly_pledges", "students"
  add_foreign_key "payer_mappings", "grades"
  add_foreign_key "payer_mappings", "students"
  add_foreign_key "payments", "grades"
  add_foreign_key "payments", "payer_mappings"
  add_foreign_key "payments", "students"
  add_foreign_key "student_accesses", "students"
  add_foreign_key "student_accesses", "users"
  add_foreign_key "students", "grades"
  add_foreign_key "trip_cost_entries", "trips"
  add_foreign_key "trips", "grades"
  add_foreign_key "users", "grades"
end
