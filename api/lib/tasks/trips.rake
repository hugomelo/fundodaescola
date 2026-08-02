namespace :trips do
  # Seeds the 10 Waldorf trips (3º..12º) with their 2025 base costs from the
  # legacy spreadsheet. Idempotent per (grade, name).
  #   bundle exec rails trips:seed GRADE_NAME="Turma da Nina"
  desc "Seed trips + 2025 base costs for a grade"
  task seed: :environment do
    grade = Grade.find_by!(name: ENV.fetch("GRADE_NAME", "Turma da Nina"))
    grade.update!(inflation_rate: 0.06) if grade.inflation_rate.to_f.zero?

    base_year = 2025
    # [level, name, trip_year, base cost per student in 2025 (reais)]
    data = [
      ["3º",  "Conchas",                        2026,   60.00],
      ["4º",  "Botucatu",                        2027,   75.95],
      ["5º",  "Ilha do Cardoso / Jogos Gregos",  2028, 2164.58],
      ["6º",  "Itú / Itatiaia",                  2029, 3400.00],
      ["7º",  "Petar",                           2030, 1507.23],
      ["8º",  "Pós-Teatro",                      2031, 1978.24],
      ["9º",  "Minas Gerais",                    2032, 4100.00],
      ["10º", "Sítio Agrimensura",               2033,  727.00],
      ["11º", "Viagem Parsifal",                 2034, 2290.06],
      ["12º", "Europa",                          2035,    0.00],
    ]

    data.each_with_index do |(level, name, year, base), i|
      trip = grade.trips.find_or_initialize_by(name: name)
      trip.assign_attributes(level: level, trip_year: year, position: i + 1)
      trip.save!
      entry = trip.cost_entries.find_or_initialize_by(year: base_year)
      entry.update!(amount_cents: (base * 100).round)
    end

    plan = CostPlan.call(grade.reload)
    puts "Trips: #{grade.trips.count}"
    puts "Total por aluno: R$ #{format('%.2f', plan[:total_per_student_cents] / 100.0)}"
    puts "Alunos ativos: #{plan[:active_students]}"
    puts "Total a acumular: R$ #{format('%.2f', plan[:total_needed_cents] / 100.0)}"
  end
end
