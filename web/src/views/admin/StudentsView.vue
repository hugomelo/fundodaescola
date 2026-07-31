<script setup>
import { ref, watch } from "vue";
import client from "../../api/client";
import { useAdminStore } from "../../stores/admin";
import { brl, monthLabel } from "../../utils/format";

const admin = useAdminStore();
const students = ref([]);
const showForm = ref(false);
const form = ref({ full_name: "", display_name: "", enrolled_from: "", enrolled_until: "" });

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
      <h2>Alunos <span class="muted" style="font-weight:400">({{ students.length }})</span></h2>
      <button @click="showForm = !showForm">{{ showForm ? "Cancelar" : "Novo aluno" }}</button>
    </div>

    <form v-if="showForm" class="new-form" @submit.prevent="create">
      <input v-model="form.full_name" placeholder="Nome completo" required />
      <input v-model="form.display_name" placeholder="Nome de exibição (opcional)" />
      <label>Início <input v-model="form.enrolled_from" type="date" /></label>
      <label>Saída <input v-model="form.enrolled_until" type="date" /></label>
      <button type="submit">Salvar</button>
    </form>

    <table>
      <thead>
        <tr><th>Nome</th><th>Período</th><th class="right">Contribuído</th><th class="right">Saldo</th><th></th></tr>
      </thead>
      <tbody>
        <tr v-for="s in students" :key="s.id">
          <td>
            <RouterLink :to="{ name: 'admin-student', params: { id: s.id } }">{{ s.full_name }}</RouterLink>
            <span v-if="!s.active" class="badge red" style="margin-left:.4rem">inativo</span>
          </td>
          <td class="muted">{{ monthLabel(s.enrolled_from) || "—" }} → {{ monthLabel(s.enrolled_until) || "atual" }}</td>
          <td class="right">{{ s.contributed_cents != null ? brl(s.contributed_cents) : "—" }}</td>
          <td class="right">—</td>
          <td class="right"><button class="ghost" @click="toggleActive(s)">{{ s.active ? "Desativar" : "Ativar" }}</button></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.new-form { display: flex; gap: 0.6rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; padding: 1rem; background: #faf7f0; border-radius: 8px; }
.new-form label { display: flex; flex-direction: column; font-size: 0.8rem; color: var(--muted); }
</style>
