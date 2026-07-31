<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { useAuthStore } from "../../stores/auth";

const admin = useAdminStore();
const auth = useAuthStore();
const users = ref([]);
const students = ref([]);
const showForm = ref(false);
const form = ref({ email: "", name: "", role: "parent", grade_id: "", password: "", student_ids: [] });

async function loadStudents() {
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/students`);
  students.value = data.students;
}
async function load() {
  const { data } = await client.get(`/admin/users`);
  users.value = data.users;
}
watch(() => admin.currentGradeId, async () => { await loadStudents(); await load(); }, { immediate: true });

const roleLabels = { super_admin: "Admin geral", grade_admin: "Coordenador", parent: "Responsável" };
const canManageRoles = computed(() => auth.isSuperAdmin);

async function create() {
  const payload = { ...form.value };
  if (!auth.isSuperAdmin) { payload.role = "parent"; delete payload.grade_id; }
  if (payload.role !== "grade_admin") delete payload.grade_id;
  await client.post(`/admin/users`, { user: payload });
  form.value = { email: "", name: "", role: "parent", grade_id: "", password: "", student_ids: [] };
  showForm.value = false;
  await load();
}

// Super admin: change a user's role inline.
async function changeRole(u, role) {
  const payload = { role };
  // A coordinator needs a grade; default to the currently selected one.
  if (role === "grade_admin") payload.grade_id = u.grade_id || admin.currentGradeId;
  await client.patch(`/admin/users/${u.id}`, { user: payload });
  await load();
}

async function changeGrade(u, gradeId) {
  await client.patch(`/admin/users/${u.id}`, { user: { grade_id: Number(gradeId) } });
  await load();
}

async function remove(u) {
  if (!confirm(`Remover ${u.email}?`)) return;
  await client.delete(`/admin/users/${u.id}`);
  await load();
}

function gradeName(id) {
  return admin.grades.find((g) => g.id === id)?.name || "—";
}
</script>

<template>
  <div class="card">
    <div class="title-row">
      <h2>Usuários <span class="muted" style="font-weight:400">({{ users.length }})</span></h2>
      <button @click="showForm = !showForm">{{ showForm ? "Cancelar" : "Novo usuário" }}</button>
    </div>

    <form v-if="showForm" class="new-form" @submit.prevent="create">
      <input v-model="form.email" type="email" placeholder="E-mail" required />
      <input v-model="form.name" placeholder="Nome" />
      <input v-model="form.password" type="password" placeholder="Senha" required />
      <select v-if="canManageRoles" v-model="form.role">
        <option value="parent">Responsável</option>
        <option value="grade_admin">Coordenador da turma</option>
        <option value="super_admin">Admin geral</option>
      </select>
      <select v-if="canManageRoles && form.role === 'grade_admin'" v-model="form.grade_id">
        <option value="" disabled>Turma do coordenador</option>
        <option v-for="g in admin.grades" :key="g.id" :value="g.id">{{ g.name }}</option>
      </select>
      <label class="students-pick" v-if="form.role === 'parent'">
        <span class="muted">Alunos vinculados</span>
        <select v-model="form.student_ids" multiple size="4">
          <option v-for="s in students" :key="s.id" :value="s.id">{{ s.full_name }}</option>
        </select>
      </label>
      <button type="submit">Salvar</button>
    </form>

    <table>
      <thead><tr><th>E-mail</th><th>Nome</th><th>Papel</th><th>Turma / Alunos</th><th></th></tr></thead>
      <tbody>
        <tr v-for="u in users" :key="u.id">
          <td>{{ u.email }}</td>
          <td>{{ u.name }}</td>
          <td>
            <select v-if="canManageRoles && u.id !== auth.user.id" :value="u.role" @change="changeRole(u, $event.target.value)">
              <option value="parent">Responsável</option>
              <option value="grade_admin">Coordenador</option>
              <option value="super_admin">Admin geral</option>
            </select>
            <span v-else class="badge">{{ roleLabels[u.role] || u.role }}</span>
          </td>
          <td class="muted">
            <template v-if="u.role === 'grade_admin'">
              <select v-if="canManageRoles" :value="u.grade_id || ''" @change="changeGrade(u, $event.target.value)">
                <option v-for="g in admin.grades" :key="g.id" :value="g.id">{{ g.name }}</option>
              </select>
              <span v-else>{{ gradeName(u.grade_id) }}</span>
            </template>
            <span v-else-if="u.role === 'parent'">{{ (u.students || []).map(s => s.display_name).join(", ") || "—" }}</span>
            <span v-else>—</span>
          </td>
          <td class="right"><button class="ghost" @click="remove(u)">✕</button></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: flex-end; margin-bottom: 1rem; padding: 1rem; background: #faf7f0; border-radius: 8px; }
.students-pick { display: flex; flex-direction: column; font-size: 0.8rem; }
</style>
