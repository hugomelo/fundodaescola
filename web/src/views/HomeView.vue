<script setup>
import { computed, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "../stores/auth";
import GradeOverview from "../components/GradeOverview.vue";

const auth = useAuthStore();
const router = useRouter();

const students = computed(() => auth.students);
const gradeId = computed(() => students.value[0]?.grade_id || auth.user?.grade_id);

onMounted(async () => {
  if (!auth.user) await auth.fetchMe();
  // A parent with exactly one student goes straight to their page.
  if (auth.isParent && auth.students.length === 1) {
    router.replace({ name: "student", params: { id: auth.students[0].id } });
  }
});
</script>

<template>
  <div class="container">
    <h1>Olá, {{ auth.user?.name || "responsável" }} 🌻</h1>
    <p class="muted">Acompanhe as contribuições e o progresso do fundo de viagens.</p>

    <div v-if="students.length" class="grid cols-3 students">
      <RouterLink
        v-for="s in students"
        :key="s.id"
        :to="{ name: 'student', params: { id: s.id } }"
        class="card student-card"
      >
        <span class="avatar">{{ (s.display_name || '?')[0] }}</span>
        <div>
          <div class="name">{{ s.display_name }}</div>
          <div class="muted">Ver contribuições</div>
        </div>
      </RouterLink>
    </div>

    <div v-if="auth.isAdmin" class="card admin-cta">
      <div>
        <strong>Você é administrador desta turma.</strong>
        <div class="muted">Gerencie pagamentos, alunos, mapeamentos e mais.</div>
      </div>
      <button @click="router.push('/admin')">Abrir administração</button>
    </div>

    <div style="margin-top: 1.5rem" v-if="gradeId">
      <GradeOverview :grade-id="gradeId" />
    </div>
  </div>
</template>

<style scoped>
.students { margin: 1.5rem 0; }
.student-card { display: flex; align-items: center; gap: 0.9rem; text-decoration: none; color: inherit; }
.student-card:hover { text-decoration: none; border-color: var(--amber); }
.avatar {
  width: 44px; height: 44px; border-radius: 50%; display: grid; place-items: center;
  background: var(--amber-soft); color: var(--amber); font-weight: 700; font-size: 1.2rem;
}
.name { font-weight: 600; }
.admin-cta { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-top: 1rem; }
</style>
