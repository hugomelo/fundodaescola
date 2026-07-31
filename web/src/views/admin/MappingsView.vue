<script setup>
import { ref, watch } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";

const admin = useAdminStore();
const mappings = ref([]);
const students = ref([]);
const form = ref({ payer_text: "", target: "" });

async function loadStudents() {
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/students`);
  students.value = data.students;
}
async function load() {
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/payer_mappings`);
  mappings.value = data.payer_mappings;
}
watch(() => admin.currentGradeId, async () => { await loadStudents(); await load(); }, { immediate: true });

function payload(target) {
  return target === "event"
    ? { maps_to_event: true, student_id: null }
    : { maps_to_event: false, student_id: Number(target) };
}

async function create() {
  await client.post(`/admin/grades/${admin.currentGradeId}/payer_mappings`, {
    apply_existing: true,
    payer_mapping: { payer_text: form.value.payer_text, ...payload(form.value.target) },
  });
  form.value = { payer_text: "", target: "" };
  await load();
}

async function update(m, target) {
  await client.patch(`/admin/payer_mappings/${m.id}`, { apply_existing: true, payer_mapping: payload(target) });
  await load();
}

async function remove(m) {
  if (!confirm(`Remover mapeamento de "${m.payer_text}"?`)) return;
  await client.delete(`/admin/payer_mappings/${m.id}`);
  await load();
}

function nameFor(m) {
  if (m.maps_to_event) return "Evento";
  return students.value.find((s) => s.id === m.student_id)?.full_name || "—";
}
</script>

<template>
  <div class="card">
    <div class="title-row"><h2>Mapeamentos de pagador</h2></div>
    <p class="muted">Associe o nome que aparece no extrato ao aluno (ou a "Evento"). Novas importações usam essas regras automaticamente.</p>

    <form class="new-form" @submit.prevent="create">
      <input v-model="form.payer_text" placeholder="Nome no extrato (pagador)" required />
      <select v-model="form.target" required>
        <option value="" disabled>Destino</option>
        <option value="event">Evento</option>
        <option v-for="s in students" :key="s.id" :value="s.id">{{ s.full_name }}</option>
      </select>
      <button type="submit">Adicionar</button>
    </form>

    <table>
      <thead><tr><th>Pagador</th><th>Destino</th><th></th></tr></thead>
      <tbody>
        <tr v-for="m in mappings" :key="m.id">
          <td>{{ m.payer_text }}</td>
          <td>
            <select :value="m.maps_to_event ? 'event' : (m.student_id || '')" @change="update(m, $event.target.value)">
              <option value="event">Evento</option>
              <option v-for="s in students" :key="s.id" :value="s.id">{{ s.full_name }}</option>
            </select>
          </td>
          <td class="right"><button class="ghost" @click="remove(m)">✕</button></td>
        </tr>
      </tbody>
    </table>
    <p v-if="!mappings.length" class="muted center" style="padding:1rem">Nenhum mapeamento cadastrado.</p>
  </div>
</template>

<style scoped>
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; margin: 1rem 0; padding: 1rem; background: #faf7f0; border-radius: 8px; }
</style>
