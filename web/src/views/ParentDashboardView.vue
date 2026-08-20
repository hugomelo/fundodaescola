<script setup>
import { ref, watch, computed } from "vue";
import client from "../api/client";
import { brl } from "../utils/format";
import GradeOverview from "../components/GradeOverview.vue";
import TripFundAbout from "../components/TripFundAbout.vue";
import StudentMonthlyTable from "../components/StudentMonthlyTable.vue";

const props = defineProps({ id: { type: [Number, String], required: true } });

const summary = ref(null);
const error = ref("");
const loading = ref(true);

const sections = [
  { id: "mes-a-mes", label: "Mês a mês" },
  { id: "panorama", label: "Panorama" },
  { id: "viagens", label: "As Viagens" },
  { id: "poupanca", label: "A Poupança" },
];

async function load() {
  loading.value = true;
  error.value = "";
  try {
    const { data } = await client.get(`/students/${props.id}/summary`);
    summary.value = data;
  } catch (e) {
    error.value = e.response?.status === 403 ? "Você não tem acesso a este aluno." : "Não foi possível carregar os dados.";
  } finally {
    loading.value = false;
  }
}
watch(() => props.id, load, { immediate: true });

const totals = computed(() => summary.value?.totals);
const balance = computed(() => totals.value?.balance_cents ?? 0);
const ahead = computed(() => balance.value >= 0);

// per-month running balance for context
const rows = computed(() => summary.value?.months || []);
const bankUpdatedThrough = computed(() => summary.value?.bank_updated_through);

function goToSection(id) {
  const el = document.getElementById(id);
  if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
}
</script>

<template>
  <div class="container">
    <RouterLink to="/" class="muted back">← Voltar</RouterLink>

    <div v-if="loading" class="muted">Carregando...</div>
    <p v-else-if="error" class="negative">{{ error }}</p>

    <template v-else-if="summary">
      <div class="title-row">
        <h1>{{ summary.student.display_name }}</h1>
        <span class="badge" :class="ahead ? 'green' : 'red'">
          {{ ahead ? "Em dia / adiantado" : "Em atraso" }}
        </span>
      </div>

      <nav class="page-nav" aria-label="Seções da página">
        <button
          v-for="s in sections"
          :key="s.id"
          type="button"
          class="nav-link"
          @click="goToSection(s.id)"
        >
          {{ s.label }}
        </button>
      </nav>

      <div id="resumo" class="grid cols-3 section-anchor">
        <div class="card stat">
          <span class="value">{{ brl(totals.contributed_cents, totals.currency) }}</span>
          <span class="label">Total contribuído</span>
        </div>
        <div class="card stat">
          <span class="value">{{ brl(totals.expected_cents, totals.currency) }}</span>
          <span class="label">Esperado até o mês atual</span>
        </div>
        <div class="card stat">
          <span class="value" :class="ahead ? 'positive' : 'negative'">
            {{ ahead ? "+" : "" }}{{ brl(balance, totals.currency) }}
          </span>
          <span class="label">{{ ahead ? "Adiantado / saldo" : "Faltando" }}</span>
        </div>
      </div>

      <div style="margin-top: 1.5rem">
        <StudentMonthlyTable
          section-id="mes-a-mes"
          :rows="rows"
          :currency="totals.currency"
          :bank-updated-through="bankUpdatedThrough"
        />
      </div>

      <div id="panorama" class="section-anchor" style="margin-top: 1.5rem">
        <GradeOverview :grade-id="summary.student.grade_id" />
      </div>

      <div style="margin-top: 1.5rem">
        <TripFundAbout />
      </div>
    </template>
  </div>
</template>

<style scoped>
.back { display: inline-block; margin-bottom: 0.8rem; }
.section-anchor { scroll-margin-top: 4.5rem; }
.page-nav {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin: 0 0 1.25rem;
  padding: 0.4rem;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 10px;
  box-shadow: var(--shadow);
  position: sticky;
  top: 0.75rem;
  z-index: 5;
}
.nav-link {
  background: transparent;
  color: var(--muted);
  border: none;
  border-radius: 7px;
  padding: 0.45rem 0.75rem;
  font-size: 0.9rem;
  line-height: 1.2;
}
.nav-link:hover {
  background: #f0ebe0;
  color: var(--ink);
}
.nav-link:focus {
  outline: none;
}
.nav-link:focus-visible {
  outline: 2px solid var(--amber);
  outline-offset: -2px;
}
@media (max-width: 560px) {
  .page-nav { top: 0.4rem; }
  .nav-link { padding: 0.4rem 0.55rem; font-size: 0.82rem; }
}
</style>
