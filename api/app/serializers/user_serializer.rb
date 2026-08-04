class UserSerializer
  def self.call(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      phone: user.phone,
      role: user.role,
      grade_id: user.grade_id,
      students: user.students.map { |s| { id: s.id, display_name: s.display_name, grade_id: s.grade_id } }
    }
  end
end
