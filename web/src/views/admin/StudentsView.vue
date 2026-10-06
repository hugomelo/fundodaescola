<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { brl, monthLabel, dateLabel } from "../../utils/format";

const admin = useAdminStore();
const students = ref([]);
const onlyBehind = ref(false);
const sortKey = ref("full_name");
const contactFilter = ref("all");
const contactOn = ref("");
const activeCount = computed(() => students.value.filter((s) => s.active).length);
const showForm = ref(false);
const form = ref({ full_name: "", display_name: "", enrolled_from: "", enrolled_until: "" });

function isoMonthsAgo(months) {
  const d = new Date();
  d.setMonth(d.getMonth() - months);
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

function contactParams() {
  if (contactFilter.value === "month") return { contacted_since: isoMonthsAgo(1) };
  if (contactFilter.value === "date" && contactOn.value) return { contacted_on: contactOn.value };
  return {};
}

function showContactsOnDate() {
  if (!contactOn.value) contactOn.value = isoMonthsAgo(0);
  contactFilter.value = "date";
}

function pendingCents(s) {
  if (s.expected_cents == null || s.contributed_cents == null) return null;
  return s.expected_cents - s.contributed_cents;
}

const behindCount = computed(() => students.value.filter((s) => pendingCents(s) > 0).length);
const displayed = computed(() => {
  let list = onlyBehind.value
    ? students.value.filter((s) => pendingCents(s) > 0)
    : students.value;
  return [...list].sort((a, b) => {
    if (sortKey.value === "atraso") return (pendingCents(b) || 0) - (pendingCents(a) || 0);
    if (sortKey.value === "last_contact") {
      if (a.last_contact_on === b.last_contact_on) return a.full_name.localeCompare(b.full_name, "pt-BR");
      if (!a.last_contact_on) return 1;
      if (!b.last_contact_on) return -1;
      return b.last_contact_on.localeCompare(a.last_contact_on);
    }
    return a.full_name.localeCompare(b.full_name, "pt-BR");
  });
});

const emptyMessage = computed(() => {
  if (!students.value.length) {
    if (contactFilter.value === "month") return "Nenhum aluno com contato no último mês.";
    if (contactFilter.value === "date" && contactOn.value) {
      return `Nenhum aluno com contato em ${dateLabel(contactOn.value)}.`;
    }
    return "Nenhum aluno cadastrado.";
  }
  if (onlyBehind.value) return "Nenhum aluno em atraso.";
  return "";
});

async function load() {
  if (!admin.currentGradeId) return;
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/students`, {
    params: contactParams(),
  });
  students.value = data.students;
}
watch(() => admin.currentGradeId, load, { immediate: true });
watch(() => JSON.stringify(contactParams()), load);

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
      <select v-model="sortKey">
        <option value="full_name">Ordenar por nome</option>
        <option value="atraso">Ordenar por atraso</option>
        <option value="last_contact">Ordenar por último contato</option>
      </select>
    </div>

    <div class="row filters contact-filters">
      <span class="muted filter-label">Contato</span>
      <div class="tabs">
        <button type="button" class="secondary" :class="{ active: contactFilter === 'all' }" @click="contactFilter = 'all'">Todos</button>
        <button type="button" class="secondary" :class="{ active: contactFilter === 'month' }" @click="contactFilter = 'month'">Último mês</button>
        <button type="button" class="secondary" :class="{ active: contactFilter === 'date' }" @click="showContactsOnDate">Em uma data</button>
      </div>
      <label v-if="contactFilter === 'date'" class="date-filter">
        Data do contato
        <input v-model="contactOn" type="date" />
      </label>
    </div>

    <table>
      <thead>
        <tr>
          <th>Nome</th>
          <th>Período</th>
          <th class="right">Contribuído</th>
          <th class="right">Prometido atual</th>
          <th class="right">Pendente</th>
          <th>Último contato</th>
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
          <td class="muted">{{ dateLabel(s.last_contact_on) || "—" }}</td>
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
      {{ emptyMessage }}
    </p>
  </div>
</template>

<style scoped>
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; padding: 1rem; background: #faf7f0; border-radius: 8px; }
.new-form label { display: flex; flex-direction: column; font-size: 0.8rem; color: var(--muted); }
.filters { align-items: center; justify-content: space-between; margin: 0 0 1rem; }
.contact-filters { justify-content: flex-start; align-items: flex-end; gap: 0.6rem; }
.filter-label { font-size: 0.85rem; padding-bottom: 0.45rem; }
.date-filter { display: flex; flex-direction: column; font-size: 0.8rem; color: var(--muted); gap: 0.2rem; }
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
