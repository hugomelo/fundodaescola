<script setup>
import { ref, watch, computed } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { brl } from "../../utils/format";

const admin = useAdminStore();
const trips = ref([]);
const inflation = ref(0.06);
const plan = ref(null);
const newTrip = ref({ level: "", name: "", trip_year: "", base_year: 2025, base_amount: "" });
const savedMsg = ref("");

function cents(v) {
  const n = parseFloat(String(v).replace(",", "."));
  return isNaN(n) ? 0 : Math.round(n * 100);
}

async function load() {
  const { data } = await client.get(`/admin/grades/${admin.currentGradeId}/trips`);
  trips.value = data.trips;
  inflation.value = Number(data.inflation_rate);
  const p = await client.get(`/grades/${admin.currentGradeId}/cost_plan`);
  plan.value = p.data;
}
watch(() => admin.currentGradeId, load, { immediate: true });

async function saveInflation() {
  const rate = parseFloat(String(inflation.value).replace(",", ".")) || 0;
  await client.patch(`/admin/grades/${admin.currentGradeId}`, { grade: { inflation_rate: rate } });
  savedMsg.value = "Inflação salva.";
  setTimeout(() => (savedMsg.value = ""), 2000);
  await load();
}

async function addTrip() {
  await client.post(`/admin/grades/${admin.currentGradeId}/trips`, {
    trip: {
      name: newTrip.value.name,
      level: newTrip.value.level,
      trip_year: Number(newTrip.value.trip_year),
      base_year: Number(newTrip.value.base_year),
      base_amount_cents: cents(newTrip.value.base_amount),
    },
  });
  newTrip.value = { level: "", name: "", trip_year: "", base_year: 2025, base_amount: "" };
  await load();
}

async function removeTrip(t) {
  if (!confirm(`Remover a viagem "${t.name}"?`)) return;
  await client.delete(`/admin/trips/${t.id}`);
  await load();
}

// Set/override a real cost for a given year.
async function setRealCost(trip, year, value) {
  await client.post(`/admin/trips/${trip.id}/cost_entries`, {
    cost_entry: { year: Number(year), amount_cents: cents(value) },
  });
  await load();
}

async function useAsTarget() {
  await client.patch(`/admin/grades/${admin.currentGradeId}`, {
    grade: { target_total_cents: plan.value.total_needed_cents },
  });
  await admin.loadGrades();
  savedMsg.value = "Meta da turma atualizada com o total do plano.";
  setTimeout(() => (savedMsg.value = ""), 3000);
}

const totalPerStudent = computed(() => plan.value?.total_per_student_cents || 0);
</script>

<template>
  <div>
    <div class="card">
      <div class="title-row">
        <h2>Plano de custos das viagens</h2>
        <span v-if="savedMsg" class="badge green">{{ savedMsg }}</span>
      </div>
      <p class="muted">
        Cada viagem acontece num ano. O custo por aluno é o último valor real informado,
        corrigido pela inflação até o ano da viagem. Informe o custo real de cada ano para
        substituir a estimativa.
      </p>
      <div class="row" style="align-items:center; gap:.6rem">
        <label class="inline">Inflação anual (ex: 0,06)
          <input v-model="inflation" style="width:90px" />
        </label>
        <button class="secondary" @click="saveInflation">Salvar inflação</button>
      </div>
    </div>

    <div v-if="plan" class="card totals" style="margin-top:1.5rem">
      <div class="grid cols-3">
        <div class="stat"><span class="value">{{ brl(plan.total_needed_cents) }}</span><span class="label">Total a acumular</span></div>
        <div class="stat"><span class="value">{{ brl(totalPerStudent) }}</span><span class="label">Por aluno ({{ plan.active_students }} ativos)</span></div>
        <div class="stat" style="justify-content:flex-end"><button @click="useAsTarget">Usar como meta da turma</button></div>
      </div>
    </div>

    <div class="card" style="margin-top:1.5rem">
      <h3>Viagens</h3>
      <table>
        <thead>
          <tr>
            <th>Ano</th><th>Viagem</th><th class="center">Ano viagem</th>
            <th class="right">Base ({{ trips[0]?.entries?.[0]?.year || 2025 }})</th>
            <th class="right">Custo estimado</th>
            <th class="right">Custo real do ano</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="t in trips" :key="t.id">
            <td>{{ t.level }}</td>
            <td>{{ t.name }}</td>
            <td class="center">{{ t.trip_year }}</td>
            <td class="right muted">{{ t.entries.length ? brl(t.entries[0].amount_cents) : "—" }}</td>
            <td class="right">
              {{ brl(t.cost_cents) }}
              <span class="badge" :class="t.is_actual ? 'green' : ''">{{ t.is_actual ? "real" : "est." }}</span>
            </td>
            <td class="right">
              <input
                style="width:110px; text-align:right"
                :placeholder="'valor ' + t.trip_year"
                @change="setRealCost(t, t.trip_year, $event.target.value)"
              />
            </td>
            <td class="right"><button class="ghost" @click="removeTrip(t)">✕</button></td>
          </tr>
        </tbody>
      </table>

      <form class="new-form" @submit.prevent="addTrip">
        <input v-model="newTrip.level" placeholder="Ano (ex: 5º)" style="width:80px" />
        <input v-model="newTrip.name" placeholder="Nome da viagem" required />
        <input v-model="newTrip.trip_year" type="number" placeholder="Ano viagem" style="width:110px" required />
        <input v-model="newTrip.base_year" type="number" placeholder="Ano base" style="width:100px" />
        <input v-model="newTrip.base_amount" placeholder="Custo base (R$)" style="width:130px" />
        <button type="submit">Adicionar viagem</button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.inline { display: flex; flex-direction: column; font-size: 0.8rem; color: var(--muted); }
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; margin-top: 1rem; padding: 1rem; background: #faf7f0; border-radius: 8px; }
.totals .stat .value { font-size: 1.4rem; }
</style>
