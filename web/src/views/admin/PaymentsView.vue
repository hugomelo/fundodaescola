<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { brl, dateLabel } from "../../utils/format";

const PAGE_SIZE = 50;

const admin = useAdminStore();
const payments = ref([]);
const total = ref(0);
const page = ref(1);
const reviewCount = ref(0);
const students = ref([]);
const filter = ref("");
const q = ref("");
const importing = ref(false);
const importResult = ref(null);
const fileInput = ref(null);

const totalPages = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));
const rangeStart = computed(() => (total.value === 0 ? 0 : (page.value - 1) * PAGE_SIZE + 1));
const rangeEnd = computed(() => Math.min(page.value * PAGE_SIZE, total.value));

async function loadStudents() {
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/students`);
  students.value = data.students;
}

async function load() {
  const params = { page: page.value, limit: PAGE_SIZE };
  if (filter.value === "event") params.kind = "event";
  if (filter.value === "contribution") params.kind = "student_contribution";
  if (filter.value === "unmapped") params.unmapped = 1;
  if (filter.value === "review") params.review = 1;
  if (q.value) params.q = q.value;
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/payments`, { params });
  payments.value = data.payments;
  total.value = data.total;
  page.value = data.page || page.value;
  reviewCount.value = data.review_count;
}

function resetAndLoad() {
  page.value = 1;
  return load();
}

watch(() => admin.currentGradeId, async () => {
  page.value = 1;
  await loadStudents();
  await load();
}, { immediate: true });
watch(filter, resetAndLoad);

let qTimer;
watch(q, () => {
  clearTimeout(qTimer);
  qTimer = setTimeout(resetAndLoad, 300);
});

async function goToPage(next) {
  const clamped = Math.min(Math.max(1, next), totalPages.value);
  if (clamped === page.value) return;
  page.value = clamped;
  await load();
}

async function remap(p, value) {
  const patch = value === "event"
    ? { kind: "event", student_id: null }
    : { kind: "student_contribution", student_id: Number(value) };
  await client.patch(`/admin/payments/${p.id}`, { payment: patch });
  await load();
}

async function updateAmount(p, value) {
  const cents = Math.round(parseFloat(String(value).replace(",", ".")) * 100);
  if (Number.isNaN(cents) || cents === p.amount_cents) return;
  await client.patch(`/admin/payments/${p.id}`, { payment: { amount_cents: cents } });
  await load();
}

// Confirm the current classification is correct (clears the review flag).
async function confirmPayment(p) {
  await client.patch(`/admin/payments/${p.id}`, { payment: { needs_review: false } });
  await load();
}

async function removePayment(p) {
  if (!confirm(`Excluir o pagamento de ${p.description}?`)) return;
  await client.delete(`/admin/payments/${p.id}`);
  await load();
}

async function onFile(e) {
  const file = e.target.files[0];
  if (!file) return;
  importing.value = true;
  importResult.value = null;
  try {
    const form = new FormData();
    form.append("file", file);
    const { data } = await client.post(`/admin/grades/${admin.currentGradeId}/payments/import`, form);
    importResult.value = data.result;
    if (data.result.flagged > 0) filter.value = "review";
    else await resetAndLoad();
  } finally {
    importing.value = false;
    if (fileInput.value) fileInput.value.value = "";
  }
}
</script>

<template>
  <div class="card">
    <div class="title-row">
      <h2>Pagamentos <span class="muted" style="font-weight:400">({{ total }})</span></h2>
      <label class="import-btn">
        {{ importing ? "Importando..." : "Importar CSV do banco" }}
        <input ref="fileInput" type="file" accept=".csv,text/csv" hidden @change="onFile" :disabled="importing" />
      </label>
    </div>

    <p v-if="importResult" class="badge green">
      Importado: {{ importResult.created }} novo(s), {{ importResult.updated }} atualizado(s),
      {{ importResult.skipped }} inalterado(s)<span v-if="importResult.ignored">, {{ importResult.ignored }} movimentação(ões) de investimento ignorada(s)</span>
      — <strong>{{ importResult.flagged }} para revisar</strong>.
    </p>

    <div v-if="reviewCount > 0 && filter !== 'review'" class="review-banner">
      ⚠️ {{ reviewCount }} pagamento(s) precisam de revisão (dias de evento ou pagador não identificado).
      <button class="secondary" @click="filter = 'review'">Revisar agora</button>
    </div>

    <div class="row filters">
      <div class="tabs">
        <button class="secondary" :class="{ active: filter === '' }" @click="filter = ''">Todos</button>
        <button class="secondary" :class="{ active: filter === 'contribution' }" @click="filter = 'contribution'">Contribuições</button>
        <button class="secondary" :class="{ active: filter === 'event' }" @click="filter = 'event'">Eventos</button>
        <button class="secondary" :class="{ active: filter === 'unmapped' }" @click="filter = 'unmapped'">Não identificados</button>
        <button class="secondary review-tab" :class="{ active: filter === 'review' }" @click="filter = 'review'">
          Revisar <span v-if="reviewCount" class="pill">{{ reviewCount }}</span>
        </button>
      </div>
      <input v-model="q" placeholder="Buscar por nome do pagador..." />
    </div>

    <table>
      <thead>
        <tr><th>Data</th><th>Descrição (pagador)</th><th class="right">Valor</th><th>Destino</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="p in payments" :key="p.id" :class="{ flagged: p.needs_review }">
          <td>{{ dateLabel(p.paid_on) }}</td>
          <td>
            <span v-if="p.needs_review" title="Precisa de revisão">⚠️</span>
            {{ p.description }}
          </td>
          <td class="right">
            <input
              class="amount-input"
              :class="{ negative: p.amount_cents < 0 }"
              :value="(p.amount_cents / 100).toFixed(2)"
              @change="updateAmount(p, $event.target.value)"
            />
          </td>
          <td>
            <select
              :value="p.kind === 'event' ? 'event' : (p.student_id || '')"
              @change="remap(p, $event.target.value)"
              :class="{ warn: p.kind === 'student_contribution' && !p.student_id }"
            >
              <option value="" disabled>— identificar —</option>
              <option value="event">Evento</option>
              <option v-for="s in students" :key="s.id" :value="s.id">{{ s.full_name }}</option>
            </select>
          </td>
          <td class="right actions">
            <button v-if="p.needs_review" class="secondary confirm" @click="confirmPayment(p)" title="Classificação correta">✓</button>
            <button class="ghost" @click="removePayment(p)">✕</button>
          </td>
        </tr>
      </tbody>
    </table>
    <p v-if="!payments.length" class="muted center" style="padding:1rem">Nenhum pagamento encontrado.</p>

    <div v-if="total > 0" class="pagination">
      <span class="range">{{ rangeStart }}–{{ rangeEnd }} de {{ total }}</span>
      <nav class="pager" aria-label="Paginação">
        <button type="button" class="pager-btn" :disabled="page <= 1" @click="goToPage(page - 1)">Anterior</button>
        <span class="page-label">{{ page }} / {{ totalPages }}</span>
        <button type="button" class="pager-btn" :disabled="page >= totalPages" @click="goToPage(page + 1)">Próxima</button>
      </nav>
    </div>
  </div>
</template>

<style scoped>
.import-btn { background: var(--primary); color: #fff; padding: 0.55rem 1rem; border-radius: 8px; cursor: pointer; }
.import-btn:hover { background: var(--primary-dark); }
.filters { align-items: center; justify-content: space-between; margin: 1rem 0; }
.tabs { display: flex; gap: 0.3rem; flex-wrap: wrap; }
.tabs .active { border-color: var(--amber); color: var(--ink); }
select.warn { border-color: var(--negative); background: #fbeee8; }
.review-banner {
  display: flex; align-items: center; justify-content: space-between; gap: 1rem;
  background: var(--amber-soft); color: var(--amber); border-radius: 8px; padding: 0.7rem 1rem; margin: 0.8rem 0;
}
.review-tab .pill { background: var(--negative); color: #fff; border-radius: 999px; padding: 0 0.4rem; font-size: 0.75rem; margin-left: 0.3rem; }
tr.flagged { background: #fdf6ea; }
.actions { display: flex; gap: 0.3rem; justify-content: flex-end; }
.confirm { color: var(--positive); border-color: var(--positive); padding: 0.35rem 0.6rem; }
.amount-input {
  width: 110px;
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.amount-input.negative { color: var(--negative); }
.pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--line);
}
.range {
  color: var(--muted);
  font-size: 0.9rem;
}
.pager {
  display: inline-flex;
  align-items: center;
  gap: 0;
  border: 1px solid var(--line);
  border-radius: 8px;
  overflow: hidden;
  background: var(--surface);
}
.pager-btn {
  background: transparent;
  color: var(--ink);
  border: none;
  border-radius: 0;
  padding: 0.45rem 0.9rem;
  font-size: 0.9rem;
  line-height: 1.2;
}
.pager-btn:hover:not(:disabled) {
  background: #f0ebe0;
}
.pager-btn:focus {
  outline: none;
}
.pager-btn:focus-visible {
  outline: 2px solid var(--amber);
  outline-offset: -2px;
  z-index: 1;
}
.pager-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
  background: transparent;
}
.page-label {
  min-width: 4.5rem;
  padding: 0.45rem 0.75rem;
  text-align: center;
  font-size: 0.85rem;
  font-variant-numeric: tabular-nums;
  color: var(--muted);
  border-left: 1px solid var(--line);
  border-right: 1px solid var(--line);
  background: #faf7f0;
  user-select: none;
}
</style>
