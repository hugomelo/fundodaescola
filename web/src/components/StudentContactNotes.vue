<script setup>
import { ref, watch, computed } from "vue";
import client from "../api/client";
import { dateLabel } from "../utils/format";

const props = defineProps({ studentId: { type: [Number, String], required: true } });

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
  const { data } = await client.get(`/admin/students/${props.studentId}/notes`);
  notes.value = data.notes;
}
watch(() => props.studentId, load, { immediate: true });

const notesByDate = computed(() => {
  const groups = [];
  for (const n of notes.value) {
    const last = groups[groups.length - 1];
    if (last && last.date === n.occurred_on) last.items.push(n);
    else groups.push({ date: n.occurred_on, items: [n] });
  }
  return groups;
});

const lastContactOn = computed(() => notes.value[0]?.occurred_on || null);

function authorName(n) {
  return n.author?.name || n.author?.email || "Coordenação";
}

async function addNote() {
  const body = noteForm.value.body.trim();
  if (!body) return;
  savingNote.value = true;
  noteError.value = "";
  try {
    await client.post(`/admin/students/${props.studentId}/notes`, {
      note: { body, occurred_on: noteForm.value.occurred_on },
    });
    noteForm.value = { occurred_on: todayISO(), body: "" };
    await load();
  } catch (e) {
    noteError.value = e.response?.data?.details?.join(", ") || "Não foi possível salvar o contato.";
  } finally {
    savingNote.value = false;
  }
}

async function removeNote(n) {
  if (!confirm("Remover este contato?")) return;
  await client.delete(`/admin/notes/${n.id}`);
  notes.value = notes.value.filter((item) => item.id !== n.id);
}
</script>

<template>
  <div class="card">
    <h3>Contatos com os responsáveis</h3>
    <p class="muted" style="margin:.2rem 0 .8rem">
      Cada registro marca um contato. A data mais recente vira o último contato do aluno
      e aparece no filtro da lista de alunos.
    </p>
    <p v-if="lastContactOn" class="last-contact">
      Último contato: <strong>{{ dateLabel(lastContactOn) }}</strong>
    </p>
    <p v-else class="muted">Nenhum contato registrado ainda.</p>

    <form class="note-form" @submit.prevent="addNote">
      <label>Data do contato
        <input v-model="noteForm.occurred_on" type="date" required />
      </label>
      <textarea
        v-model="noteForm.body"
        rows="4"
        required
        placeholder="O que foi conversado com a família…"
      />
      <div class="note-form-actions">
        <button type="submit" :disabled="savingNote || !noteForm.body.trim()">
          {{ savingNote ? "Salvando…" : "Registrar contato" }}
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
  </div>
</template>

<style scoped>
.last-contact { margin: 0 0 0.8rem; }
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
