<script setup>
import { ref, watch } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { dateLabel } from "../../utils/format";

const admin = useAdminStore();
const events = ref([]);
const form = ref({ name: "", starts_on: "", ends_on: "" });
const lastFlagged = ref(null);

async function load() {
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/events`);
  events.value = data.events;
}
watch(() => admin.currentGradeId, load, { immediate: true });

async function create() {
  const payload = { name: form.value.name, starts_on: form.value.starts_on };
  if (form.value.ends_on) payload.ends_on = form.value.ends_on;
  const { data } = await client.post(`/admin/grades/${admin.currentGradeId}/events`, {
    event: payload,
    flag_payments: true,
  });
  lastFlagged.value = data.flagged;
  form.value = { name: "", starts_on: "", ends_on: "" };
  await load();
}

async function remove(e) {
  if (!confirm(`Remover o evento "${e.name}"?`)) return;
  await client.delete(`/admin/events/${e.id}`);
  await load();
}
</script>

<template>
  <div class="card">
    <div class="title-row"><h2>Eventos</h2></div>
    <p class="muted">
      Cadastre as datas dos eventos da turma. Na importação do extrato, valores iguais
      ou acima do valor prometido do aluno entram como contribuição; valores menores
      nesses dias entram como evento e pedem confirmação (ex.: um pedaço de bolo).
    </p>

    <form class="new-form" @submit.prevent="create">
      <input v-model="form.name" placeholder="Nome do evento (ex: Festa Junina)" required />
      <label>Data <input v-model="form.starts_on" type="date" required /></label>
      <label>Fim (opcional) <input v-model="form.ends_on" type="date" /></label>
      <button type="submit">Adicionar</button>
    </form>

    <p v-if="lastFlagged !== null" class="badge green">
      Evento criado. {{ lastFlagged }} pagamento(s) desse período marcado(s) para revisão.
    </p>

    <table>
      <thead><tr><th>Evento</th><th>Período</th><th></th></tr></thead>
      <tbody>
        <tr v-for="e in events" :key="e.id">
          <td>{{ e.name }}</td>
          <td class="muted">{{ dateLabel(e.starts_on) }}<span v-if="e.ends_on"> → {{ dateLabel(e.ends_on) }}</span></td>
          <td class="right"><button class="ghost" @click="remove(e)">✕</button></td>
        </tr>
      </tbody>
    </table>
    <p v-if="!events.length" class="muted center" style="padding:1rem">Nenhum evento cadastrado.</p>
  </div>
</template>

<style scoped>
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: flex-end; margin: 1rem 0; padding: 1rem; background: #faf7f0; border-radius: 8px; }
.new-form label { display: flex; flex-direction: column; font-size: 0.8rem; color: var(--muted); }
</style>
