<script setup>
import { computed } from "vue";
import { useRouter, RouterView } from "vue-router";
import { useAuthStore } from "./stores/auth";

const auth = useAuthStore();
const router = useRouter();
const authed = computed(() => auth.isAuthenticated);

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
    <nav>
      <RouterLink to="/">Início</RouterLink>
      <RouterLink v-if="auth.isAdmin" to="/admin">Administração</RouterLink>
      <span class="who muted">{{ auth.user?.name || auth.user?.email }}</span>
      <button class="ghost" @click="logout">Sair</button>
    </nav>
  </header>
  <RouterView />
</template>

<style scoped>
.topbar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 0.8rem 1.2rem; background: var(--surface); border-bottom: 1px solid var(--line);
  position: sticky; top: 0; z-index: 10;
}
.brand { font-weight: 700; font-size: 1.1rem; cursor: pointer; }
.mark { font-size: 1.2rem; }
nav { display: flex; align-items: center; gap: 1.1rem; }
.who { font-size: 0.9rem; }
@media (max-width: 560px) { .who { display: none; } }
</style>
