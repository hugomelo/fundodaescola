namespace :import do
  # Usage:
  #   bundle exec rails import:spreadsheet \
  #     GRADE_NAME="Turma da Nina" SCHOOL_NAME="Escola Waldorf" \
  #     TARGET_TOTAL=80000 \
  #     PAYMENTS_CSV=db/import_data/payments.csv \
  #     STUDENTS_CSV=db/import_data/students.csv
  desc "Import the legacy Google Spreadsheet (payments + pledges) into a grade"
  task spreadsheet: :environment do
    payments_csv = ENV.fetch("PAYMENTS_CSV", Rails.root.join("db/import_data/payments.csv").to_s)
    students_csv = ENV.fetch("STUDENTS_CSV", Rails.root.join("db/import_data/students.csv").to_s)

    grade = Grade.find_or_create_by!(name: ENV.fetch("GRADE_NAME", "Turma")) do |g|
      g.school_name = ENV.fetch("SCHOOL_NAME", "Escola Waldorf")
      g.target_total_cents = (ENV.fetch("TARGET_TOTAL", "0").to_f * 100).round
      g.currency = "BRL"
    end

    if ENV["TARGET_TOTAL"].present?
      grade.update!(target_total_cents: (ENV["TARGET_TOTAL"].to_f * 100).round)
    end

    puts "Importing into grade ##{grade.id} '#{grade.name}'..."
    SpreadsheetImporter.run(grade: grade, payments_csv: payments_csv, students_csv: students_csv)

    grade.reload
    puts "Grade net raised: R$ #{format('%.2f', grade.net_raised_cents / 100.0)}"
    puts "Students: #{grade.students.count} | Payments: #{grade.payments.count} | " \
         "Pledges: #{MonthlyPledge.joins(:student).where(students: { grade_id: grade.id }).count} | " \
         "Payer mappings: #{grade.payer_mappings.count}"
  end

  # Rebuild default payer mappings (dominant-student heuristic) and retro-apply
  # them to still-unidentified payments. Useful after importing new bank data.
  #   bundle exec rails import:rebuild_mappings GRADE_NAME="Turma da Nina"
  desc "Rebuild payer mappings and apply them to unmapped payments"
  task rebuild_mappings: :environment do
    grade = Grade.find_by!(name: ENV.fetch("GRADE_NAME", "Turma"))
    result = SpreadsheetImporter.rebuild_mappings(grade: grade)
    puts "Payer mappings: #{result[:mappings]} | Payments newly mapped: #{result[:applied]}"
  end
end
