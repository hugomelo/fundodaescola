<script setup>
import { computed, watch } from "vue";
import { useRouter, useRoute, RouterView } from "vue-router";
import { useAuthStore } from "./stores/auth";

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();
const authed = computed(() => auth.isAuthenticated);
const showStudentSwitch = computed(() => auth.isParent && auth.students.length > 1);
const switchValue = computed(() => {
  if (route.name === "student" && route.params.id) return Number(route.params.id);
  return auth.selectedStudent?.id ?? "";
});

function studentLabel(student) {
  return student.grade_name ? `${student.display_name} — ${student.grade_name}` : student.display_name;
}

function switchStudent(id) {
  auth.selectStudent(id);
  const student = auth.students.find((s) => s.id === Number(id));
  if (route.name === "cost-plan" && student?.grade_id) {
    router.push({ name: "cost-plan", params: { gradeId: student.grade_id } });
    return;
  }
  if (route.name === "profile") return;
  router.push({ name: "student", params: { id } });
}

watch(
  () => [route.name, route.params.id, auth.students.map((s) => s.id).join(",")],
  () => {
    if (route.name === "student" && route.params.id) auth.selectStudent(route.params.id);
  }
);

function logout() {
  auth.logout();
  router.push({ name: "login" });
}
</script>

<template>
  <header v-if="authed" class="topbar">
    <div class="brand" @click="router.push('/')">
      <span class="mark">🌾</span> Fundo da Escola
    </div>
    <label v-if="showStudentSwitch" class="student-switch">
      <span>Aluno</span>
      <select :value="switchValue" @change="switchStudent($event.target.value)">
        <option v-for="s in auth.students" :key="s.id" :value="s.id">{{ studentLabel(s) }}</option>
      </select>
    </label>
    <nav>
      <RouterLink to="/">Início</RouterLink>
      <RouterLink v-if="auth.isAdmin" to="/admin">Administração</RouterLink>
      <RouterLink to="/perfil" class="profile-link">
        <span class="who">{{ auth.user?.name || auth.user?.email }}</span>
        <span class="profile-short">Perfil</span>
      </RouterLink>
      <button class="ghost" @click="logout">Sair</button>
    </nav>
  </header>
  <RouterView />
</template>

<style scoped>
.topbar {
  display: flex; align-items: center; justify-content: space-between; gap: 1rem;
  padding: 0.8rem 1.2rem; background: var(--surface); border-bottom: 1px solid var(--line);
  position: sticky; top: 0; z-index: 10;
}
.student-switch {
  display: flex; align-items: center; gap: 0.45rem;
  margin-left: auto; font-size: 0.85rem; color: var(--muted);
}
.student-switch select { max-width: 16rem; }
.brand { font-weight: 700; font-size: 1.1rem; cursor: pointer; }
.mark { font-size: 1.2rem; }
nav { display: flex; align-items: center; gap: 1.1rem; }
.who { font-size: 0.9rem; }
.profile-short { display: none; font-size: 0.9rem; }
@media (max-width: 720px) {
  .topbar { flex-wrap: wrap; }
  .student-switch { order: 3; width: 100%; margin-left: 0; }
  .student-switch select { flex: 1; max-width: none; }
}
@media (max-width: 560px) {
  .who { display: none; }
  .profile-short { display: inline; }
}
</style>
