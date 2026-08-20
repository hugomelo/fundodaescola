<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { brl, dateLabel } from "../../utils/format";
import StudentMonthlyTable from "../../components/StudentMonthlyTable.vue";

const props = defineProps({ id: { type: [Number, String], required: true } });

const summary = ref(null);
const error = ref("");
const loading = ref(true);
const notes = ref([]);
const savingNote = ref(false);
const noteError = ref("");

function todayISO() {
  const d = new Date();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

const noteForm = ref({ occurred_on: todayISO(), body: "" });

async function load() {
  loading.value = true;
  error.value = "";
  try {
    const [{ data }, notesRes] = await Promise.all([
      client.get(`/students/${props.id}/summary`),
      client.get(`/admin/students/${props.id}/notes`),
    ]);
    summary.value = data;
    notes.value = notesRes.data.notes;
  } catch (e) {
    error.value = e.response?.status === 403
      ? "Você não tem acesso a este aluno."
      : "Não foi possível carregar os pagamentos.";
  } finally {
    loading.value = false;
  }
}
watch(() => props.id, load, { immediate: true });

const totals = computed(() => summary.value?.totals);
const balance = computed(() => totals.value?.balance_cents ?? 0);
const ahead = computed(() => balance.value >= 0);

const notesByDate = computed(() => {
  const groups = [];
  for (const n of notes.value) {
    const last = groups[groups.length - 1];
    if (last && last.date === n.occurred_on) last.items.push(n);
    else groups.push({ date: n.occurred_on, items: [n] });
  }
  return groups;
});

function authorName(n) {
  return n.author?.name || n.author?.email || "Coordenação";
}

async function addNote() {
  const body = noteForm.value.body.trim();
  if (!body) return;
  savingNote.value = true;
  noteError.value = "";
  try {
    await client.post(`/admin/students/${props.id}/notes`, {
      note: { body, occurred_on: noteForm.value.occurred_on },
    });
    noteForm.value = { occurred_on: todayISO(), body: "" };
    const { data } = await client.get(`/admin/students/${props.id}/notes`);
    notes.value = data.notes;
  } catch (e) {
    noteError.value = e.response?.data?.details?.join(", ") || "Não foi possível salvar a nota.";
  } finally {
    savingNote.value = false;
  }
}

async function removeNote(n) {
  if (!confirm("Remover esta nota?")) return;
  await client.delete(`/admin/notes/${n.id}`);
  notes.value = notes.value.filter((item) => item.id !== n.id);
}
</script>

<template>
  <div>
    <RouterLink :to="{ name: 'admin-students' }" class="muted">← Alunos</RouterLink>

    <div v-if="loading" class="muted" style="margin-top:.8rem">Carregando...</div>
    <p v-else-if="error" class="negative">{{ error }}</p>

    <template v-else-if="summary">
      <div class="title-row" style="margin-top:.5rem">
        <h2>{{ summary.student.full_name }}</h2>
        <span class="badge" :class="ahead ? 'green' : 'red'">
          {{ ahead ? "Em dia / adiantado" : "Em atraso" }}
        </span>
      </div>

      <div class="grid cols-3">
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
          :rows="summary.months || []"
          :currency="totals.currency"
          :bank-updated-through="summary.bank_updated_through"
        />
      </div>

      <div class="card" style="margin-top: 1.5rem">
        <h3>Conversas com a família</h3>
        <p class="muted" style="margin:.2rem 0 .8rem">
          Registre o que foi combinado em cada conversa.
        </p>

        <form class="note-form" @submit.prevent="addNote">
          <label>Data da conversa
            <input v-model="noteForm.occurred_on" type="date" required />
          </label>
          <textarea
            v-model="noteForm.body"
            rows="4"
            required
            placeholder="Anotações da conversa…"
          />
          <div class="note-form-actions">
            <button type="submit" :disabled="savingNote || !noteForm.body.trim()">
              {{ savingNote ? "Salvando…" : "Salvar nota" }}
            </button>
            <span v-if="noteError" class="negative">{{ noteError }}</span>
          </div>
        </form>

        <div v-if="notesByDate.length" class="notes-list">
          <section v-for="g in notesByDate" :key="g.date" class="note-day">
            <h4>{{ dateLabel(g.date) }}</h4>
            <article v-for="n in g.items" :key="n.id" class="note">
              <div class="note-meta">
                <span class="muted">{{ authorName(n) }}</span>
                <button type="button" class="ghost" @click="removeNote(n)" title="Remover">✕</button>
              </div>
              <p class="note-body">{{ n.body }}</p>
            </article>
          </section>
        </div>
        <p v-else class="muted center" style="padding:1rem">Nenhuma conversa registrada.</p>
      </div>
    </template>
  </div>
</template>

<style scoped>
.note-form {
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
  margin-bottom: 1.25rem;
  padding: 1rem;
  background: #faf7f0;
  border-radius: 8px;
}
.note-form label {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  font-size: 0.8rem;
  color: var(--muted);
  max-width: 220px;
}
.note-form textarea {
  width: 100%;
  resize: vertical;
  min-height: 6rem;
  font: inherit;
  padding: 0.5rem 0.6rem;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fff;
  color: var(--ink);
}
.note-form textarea:focus {
  outline: 2px solid var(--amber-soft);
  border-color: var(--amber);
}
.note-form-actions { display: flex; align-items: center; gap: 0.8rem; }
.notes-list { display: flex; flex-direction: column; gap: 1.25rem; }
.note-day h4 {
  margin: 0 0 0.5rem;
  font-size: 0.95rem;
  color: var(--ink);
}
.note {
  padding: 0.75rem 0.9rem;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fff;
}
.note + .note { margin-top: 0.5rem; }
.note-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.35rem;
}
.note-body {
  margin: 0;
  white-space: pre-wrap;
  line-height: 1.45;
}
</style>
