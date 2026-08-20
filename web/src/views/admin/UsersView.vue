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
const importing = ref(false);
const importResult = ref(null);
const createResult = ref(null);
const sendInvite = ref(true);
const fileInput = ref(null);

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
  if (!payload.password) delete payload.password;
  const { data } = await client.post(`/admin/users`, { user: payload, send_invite: sendInvite.value });
  form.value = { email: "", name: "", role: "parent", grade_id: "", password: "", student_ids: [] };
  showForm.value = false;
  importResult.value = null;
  createResult.value = data.invited
    ? `Usuário criado e convite enviado para ${data.user.email}.`
    : `Usuário ${data.user.email} criado.`;
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

async function onFile(e) {
  const file = e.target.files[0];
  if (!file) return;
  importing.value = true;
  importResult.value = null;
  createResult.value = null;
  try {
    const formData = new FormData();
    formData.append("file", file);
    formData.append("grade_id", admin.currentGradeId);
    formData.append("send_invite", sendInvite.value ? "true" : "false");
    const { data } = await client.post(`/admin/users/import`, formData);
    importResult.value = data.result;
    await load();
  } finally {
    importing.value = false;
    if (fileInput.value) fileInput.value.value = "";
  }
}
</script>

<template>
  <div class="card">
    <div class="title-row">
      <h2>Usuários <span class="muted" style="font-weight:400">({{ users.length }})</span></h2>
      <div class="actions-row">
        <label class="invite-check">
          <input v-model="sendInvite" type="checkbox" />
          Enviar e-mail de convite aos novos usuários
        </label>
        <label class="import-btn">
          {{ importing ? "Importando..." : "Importar CSV" }}
          <input ref="fileInput" type="file" accept=".csv,text/csv" hidden @change="onFile" :disabled="importing" />
        </label>
        <button @click="showForm = !showForm">{{ showForm ? "Cancelar" : "Novo usuário" }}</button>
      </div>
    </div>

    <p class="muted import-hint">
      CSV com colunas <code>name</code>, <code>email</code>, <code>telefone</code> (opcional) e
      <code>aluno</code> (nome do estudante na turma selecionada).
    </p>

    <p v-if="createResult" class="import-result badge green">{{ createResult }}</p>
    <p v-if="importResult" class="import-result badge green">
      Importado: {{ importResult.created }} novo(s), {{ importResult.updated }} atualizado(s),
      {{ importResult.skipped }} ignorado(s)
      <span v-if="importResult.invited"> — {{ importResult.invited }} convite(s) enviado(s)</span>.
    </p>
    <ul v-if="importResult?.errors?.length" class="import-errors">
      <li v-for="(err, i) in importResult.errors" :key="i">{{ err }}</li>
    </ul>

    <form v-if="showForm" class="new-form" @submit.prevent="create">
      <input v-model="form.email" type="email" placeholder="E-mail" required />
      <input v-model="form.name" placeholder="Nome" />
      <input
        v-model="form.password"
        type="password"
        :placeholder="sendInvite ? 'Senha (opcional — o convite define a senha)' : 'Senha'"
        :required="!sendInvite"
      />
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
.actions-row { display: flex; gap: 0.6rem; align-items: center; flex-wrap: wrap; }
.invite-check { display: flex; align-items: center; gap: 0.4rem; font-size: 0.85rem; color: var(--muted, #7a7266); cursor: pointer; }
.import-btn { background: var(--primary); color: #fff; padding: 0.55rem 1rem; border-radius: 8px; cursor: pointer; }
.import-btn:hover { background: var(--primary-dark); }
.import-hint { margin: 0.4rem 0 0.8rem; font-size: 0.85rem; }
.import-hint code { font-size: 0.8rem; background: #f0ebe3; padding: 0.1rem 0.35rem; border-radius: 4px; }
.import-result { display: block; margin-bottom: 0.6rem; }
.import-errors {
  margin: 0 0 1rem; padding: 0.7rem 1rem; background: #fbeee8; border-radius: 8px;
  color: var(--negative, #a94442); font-size: 0.85rem; list-style: disc inside;
  max-height: 10rem; overflow: auto;
}
</style>
