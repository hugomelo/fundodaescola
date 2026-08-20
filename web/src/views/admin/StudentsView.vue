<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { brl, monthLabel } from "../../utils/format";

const admin = useAdminStore();
const students = ref([]);
const onlyBehind = ref(false);
const activeCount = computed(() => students.value.filter((s) => s.active).length);
const showForm = ref(false);
const form = ref({ full_name: "", display_name: "", enrolled_from: "", enrolled_until: "" });

function pendingCents(s) {
  if (s.expected_cents == null || s.contributed_cents == null) return null;
  return s.expected_cents - s.contributed_cents;
}

const behindCount = computed(() => students.value.filter((s) => pendingCents(s) > 0).length);
const displayed = computed(() => {
  if (!onlyBehind.value) return students.value;
  return students.value.filter((s) => pendingCents(s) > 0);
});

async function load() {
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/students`);
  students.value = data.students;
}
watch(() => admin.currentGradeId, load, { immediate: true });

async function create() {
  await client.post(`/admin/grades/${admin.currentGradeId}/students`, { student: form.value });
  form.value = { full_name: "", display_name: "", enrolled_from: "", enrolled_until: "" };
  showForm.value = false;
  await load();
}

async function toggleActive(s) {
  await client.patch(`/admin/students/${s.id}`, { student: { active: !s.active } });
  await load();
}
</script>

<template>
  <div class="card">
    <div class="title-row">
      <h2>Alunos <span class="muted" style="font-weight:400">({{ activeCount }} ativos de {{ students.length }})</span></h2>
      <button @click="showForm = !showForm">{{ showForm ? "Cancelar" : "Novo aluno" }}</button>
    </div>

    <form v-if="showForm" class="new-form" @submit.prevent="create">
      <input v-model="form.full_name" placeholder="Nome completo" required />
      <input v-model="form.display_name" placeholder="Nome de exibição (opcional)" />
      <label>Início <input v-model="form.enrolled_from" type="date" /></label>
      <label>Saída <input v-model="form.enrolled_until" type="date" /></label>
      <button type="submit">Salvar</button>
    </form>

    <div class="row filters">
      <div class="tabs">
        <button type="button" class="secondary" :class="{ active: !onlyBehind }" @click="onlyBehind = false">Todos</button>
        <button type="button" class="secondary" :class="{ active: onlyBehind }" @click="onlyBehind = true">
          Em atraso <span v-if="behindCount" class="pill">{{ behindCount }}</span>
        </button>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Nome</th>
          <th>Período</th>
          <th class="right">Contribuído</th>
          <th class="right">Prometido atual</th>
          <th class="right">Pendente</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="s in displayed" :key="s.id">
          <td>
            <RouterLink :to="{ name: 'admin-student', params: { id: s.id } }">{{ s.full_name }}</RouterLink>
            <span v-if="!s.active" class="badge red" style="margin-left:.4rem">inativo</span>
          </td>
          <td class="muted">{{ monthLabel(s.enrolled_from) || "—" }} → {{ monthLabel(s.enrolled_until) || "atual" }}</td>
          <td class="right">{{ s.contributed_cents != null ? brl(s.contributed_cents) : "—" }}</td>
          <td class="right">{{ s.latest_pledge_cents != null ? brl(s.latest_pledge_cents) : "—" }}</td>
          <td
            class="right"
            :class="{
              negative: pendingCents(s) > 0,
              positive: pendingCents(s) < 0,
            }"
          >
            {{ pendingCents(s) != null ? brl(pendingCents(s)) : "—" }}
          </td>
          <td class="right actions">
            <RouterLink
              class="btn-link"
              :to="{ name: 'admin-student-payments', params: { id: s.id } }"
            >Pagamentos</RouterLink>
            <button class="ghost" @click="toggleActive(s)">{{ s.active ? "Desativar" : "Ativar" }}</button>
          </td>
        </tr>
      </tbody>
    </table>
    <p v-if="!displayed.length" class="muted center" style="padding:1rem">
      {{ onlyBehind ? "Nenhum aluno em atraso." : "Nenhum aluno cadastrado." }}
    </p>
  </div>
</template>

<style scoped>
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; padding: 1rem; background: #faf7f0; border-radius: 8px; }
.new-form label { display: flex; flex-direction: column; font-size: 0.8rem; color: var(--muted); }
.filters { align-items: center; margin: 0 0 1rem; }
.tabs { display: flex; gap: 0.3rem; flex-wrap: wrap; }
.tabs .active { border-color: var(--amber); color: var(--ink); }
.tabs .pill { background: var(--negative); color: #fff; border-radius: 999px; padding: 0 0.4rem; font-size: 0.75rem; margin-left: 0.3rem; }
.actions { display: flex; gap: 0.3rem; justify-content: flex-end; align-items: center; white-space: nowrap; }
.btn-link {
  display: inline-block;
  padding: 0.35rem 0.75rem;
  border-radius: 8px;
  border: 1px solid var(--line);
  background: var(--surface);
  color: var(--ink);
  font-size: 0.85rem;
}
.btn-link:hover { text-decoration: none; background: #f0ebe0; }
</style>
