# Idempotent seeds: a super admin, a grade admin, and a demo parent.
# Passwords come from ENV in production; defaults are for local dev only.

grade = Grade.find_by(name: ENV.fetch("SEED_GRADE_NAME", "Turma da Nina")) || Grade.first

if grade.nil?
  puts "No grade found. Run `rails import:spreadsheet` first."
else
  super_admin = User.find_or_initialize_by(email: "admin@colheita.local")
  super_admin.update!(
    name: "Administrador Geral",
    role: :super_admin,
    password: ENV.fetch("SEED_ADMIN_PASSWORD", "colheita123")
  )
  puts "Super admin: #{super_admin.email}"

  grade_admin = User.find_or_initialize_by(email: "coordenador@colheita.local")
  grade_admin.update!(
    name: "Coordenador da Turma",
    role: :grade_admin,
    grade: grade,
    password: ENV.fetch("SEED_GRADE_ADMIN_PASSWORD", "colheita123")
  )
  puts "Grade admin: #{grade_admin.email} (grade ##{grade.id})"

  # Demo parent linked to the first student that actually has contributions.
  student = grade.students.joins(:payments).distinct.order(:full_name).first || grade.students.first
  if student
    parent = User.find_or_initialize_by(email: "responsavel@colheita.local")
    parent.update!(
      name: "Responsável Demo",
      role: :parent,
      password: ENV.fetch("SEED_PARENT_PASSWORD", "colheita123")
    )
    StudentAccess.find_or_create_by!(user: parent, student: student)
    puts "Parent: #{parent.email} -> #{student.full_name} (##{student.id})"
  end
end
