<script setup>
import { onMounted, computed } from "vue";
import { RouterView } from "vue-router";
import { useAdminStore } from "../../stores/admin";
import { useAuthStore } from "../../stores/auth";

const admin = useAdminStore();
const auth = useAuthStore();
const isSuper = computed(() => auth.isSuperAdmin);

onMounted(() => { if (!admin.loaded) admin.loadGrades(); });

const links = [
  { to: { name: "admin-dashboard" }, label: "Painel" },
  { to: { name: "admin-payments" }, label: "Pagamentos" },
  { to: { name: "admin-events" }, label: "Eventos" },
  { to: { name: "admin-students" }, label: "Alunos" },
  { to: { name: "admin-mappings" }, label: "Mapeamentos" },
  { to: { name: "admin-investments" }, label: "Rendimentos" },
  { to: { name: "admin-trips" }, label: "Viagens" },
  { to: { name: "admin-users" }, label: "Usuários" },
  { to: { name: "admin-settings" }, label: "Configurações" },
];
</script>

<template>
  <div class="container">
    <div class="title-row">
      <h1>Administração</h1>
      <select v-if="isSuper && admin.grades.length" :value="admin.currentGradeId" @change="admin.setGrade($event.target.value)">
        <option v-for="g in admin.grades" :key="g.id" :value="g.id">{{ g.name }}</option>
      </select>
    </div>

    <nav class="subnav">
      <RouterLink v-for="l in links" :key="l.label" :to="l.to" class="tab">{{ l.label }}</RouterLink>
    </nav>

    <RouterView v-if="admin.currentGradeId" />
    <p v-else class="muted">Carregando turmas...</p>
  </div>
</template>

<style scoped>
.subnav { display: flex; gap: 0.4rem; flex-wrap: wrap; margin: 0.5rem 0 1.5rem; }
.tab {
  padding: 0.45rem 0.9rem; border-radius: 8px; color: var(--muted);
  border: 1px solid transparent;
}
.tab:hover { text-decoration: none; background: #f0ebe0; }
.tab.router-link-active { background: var(--surface); border-color: var(--line); color: var(--ink); box-shadow: var(--shadow); }
</style>
