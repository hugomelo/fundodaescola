<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { useAuthStore } from "../../stores/auth";
import { brl } from "../../utils/format";

const admin = useAdminStore();
const auth = useAuthStore();
const isSuper = computed(() => auth.isSuperAdmin);

const grade = ref(null);
const form = ref({});
const savedMsg = ref("");
const error = ref("");

// New-grade form (super admin only)
const newGrade = ref({ name: "", school_name: "", target: "" });
const createdMsg = ref("");

function toForm(g) {
  return {
    name: g.name,
    school_name: g.school_name || "",
    target: g.target_total_cents ? (g.target_total_cents / 100).toFixed(2) : "",
    school_year_start: g.school_year_start || "",
    school_year_end: g.school_year_end || "",
    description: g.description || "",
  };
}

async function load() {
  savedMsg.value = "";
  error.value = "";
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}`);
  grade.value = data.grade;
  form.value = toForm(data.grade);
}
watch(() => admin.currentGradeId, load, { immediate: true });

function cents(v) {
  const n = parseFloat(String(v).replace(",", "."));
  return isNaN(n) ? 0 : Math.round(n * 100);
}

async function save() {
  error.value = "";
  savedMsg.value = "";
  try {
    const payload = {
      name: form.value.name,
      school_name: form.value.school_name,
      target_total_cents: cents(form.value.target),
      description: form.value.description,
    };
    if (form.value.school_year_start) payload.school_year_start = form.value.school_year_start;
    if (form.value.school_year_end) payload.school_year_end = form.value.school_year_end;
    const { data } = await client.patch(`/admin/grades/${admin.currentGradeId}`, { grade: payload });
    grade.value = data.grade;
    await admin.loadGrades(); // refresh the name shown in the switcher
    savedMsg.value = "Alterações salvas.";
  } catch (e) {
    error.value = e.response?.data?.details?.join(", ") || "Não foi possível salvar.";
  }
}

async function createGrade() {
  createdMsg.value = "";
  try {
    const payload = {
      name: newGrade.value.name,
      school_name: newGrade.value.school_name,
      target_total_cents: cents(newGrade.value.target),
    };
    const { data } = await client.post(`/admin/grades`, { grade: payload });
    await admin.loadGrades();
    admin.setGrade(data.grade.id); // switch to the new grade
    newGrade.value = { name: "", school_name: "", target: "" };
    createdMsg.value = `Turma "${data.grade.name}" criada.`;
  } catch (e) {
    createdMsg.value = e.response?.data?.details?.join(", ") || "Não foi possível criar a turma.";
  }
}
</script>

<template>
  <div v-if="grade">
    <div class="card">
      <h2>Configurações da turma</h2>
      <div class="form-grid">
        <label>Nome da turma
          <input v-model="form.name" required />
        </label>
        <label>Escola
          <input v-model="form.school_name" />
        </label>
        <label>Meta / custo total (R$)
          <input v-model="form.target" placeholder="ex: 80000,00" />
        </label>
        <label>Início do ano letivo
          <input v-model="form.school_year_start" type="date" />
        </label>
        <label>Fim do ano letivo
          <input v-model="form.school_year_end" type="date" />
        </label>
        <label class="full">Descrição
          <input v-model="form.description" placeholder="Fundo de viagens da turma..." />
        </label>
      </div>
      <div class="row" style="align-items:center; margin-top:1rem">
        <button @click="save">Salvar alterações</button>
        <span v-if="savedMsg" class="badge green">{{ savedMsg }}</span>
        <span v-if="error" class="negative">{{ error }}</span>
        <span class="muted" style="margin-left:auto">Meta atual: {{ brl(grade.target_total_cents) }}</span>
      </div>
    </div>

    <div v-if="isSuper" class="card" style="margin-top:1.5rem">
      <h2>Criar nova turma</h2>
      <p class="muted">Cada turma tem seus próprios alunos, pagamentos e administradores.</p>
      <div class="form-grid">
        <label>Nome da turma
          <input v-model="newGrade.name" placeholder="ex: 4º Ano B" />
        </label>
        <label>Escola
          <input v-model="newGrade.school_name" placeholder="Escola Waldorf" />
        </label>
        <label>Meta / custo total (R$)
          <input v-model="newGrade.target" placeholder="ex: 80000,00" />
        </label>
      </div>
      <div class="row" style="align-items:center; margin-top:1rem">
        <button @click="createGrade">Criar turma</button>
        <span v-if="createdMsg" class="badge green">{{ createdMsg }}</span>
      </div>
    </div>

    <div v-if="isSuper" class="card" style="margin-top:1.5rem">
      <h2>Turmas</h2>
      <table>
        <thead><tr><th>Turma</th><th>Escola</th><th class="right">Meta</th><th></th></tr></thead>
        <tbody>
          <tr v-for="g in admin.grades" :key="g.id">
            <td>{{ g.name }} <span v-if="g.id === admin.currentGradeId" class="badge green">atual</span></td>
            <td class="muted">{{ g.school_name }}</td>
            <td class="right">{{ brl(g.target_total_cents) }}</td>
            <td class="right">
              <button v-if="g.id !== admin.currentGradeId" class="secondary" @click="admin.setGrade(g.id)">Selecionar</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  <p v-else class="muted">Carregando...</p>
</template>

<style scoped>
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.8rem; margin-top: 1rem; }
.form-grid label { display: flex; flex-direction: column; gap: 0.25rem; font-size: 0.85rem; color: var(--muted); }
.form-grid label.full { grid-column: 1 / -1; }
@media (max-width: 620px) { .form-grid { grid-template-columns: 1fr; } }
</style>
