<script setup>
import { ref, watch } from "vue";
import { useAuthStore } from "../stores/auth";

const auth = useAuthStore();

const profile = ref({ name: "", phone: "" });
const passwords = ref({ current: "", next: "", confirm: "" });
const profileMsg = ref("");
const profileError = ref("");
const passwordMsg = ref("");
const passwordError = ref("");
const savingProfile = ref(false);
const savingPassword = ref(false);

watch(
  () => auth.user,
  (u) => {
    if (!u) return;
    profile.value = { name: u.name || "", phone: u.phone || "" };
  },
  { immediate: true }
);

async function saveProfile() {
  profileMsg.value = "";
  profileError.value = "";
  savingProfile.value = true;
  try {
    await auth.updateProfile({
      name: profile.value.name.trim(),
      phone: profile.value.phone.trim(),
    });
    profileMsg.value = "Dados salvos.";
  } catch (e) {
    profileError.value = e.response?.data?.details?.join(" ") || "Não foi possível salvar.";
  } finally {
    savingProfile.value = false;
  }
}

async function savePassword() {
  passwordMsg.value = "";
  passwordError.value = "";
  if (passwords.value.next.length < 6) {
    passwordError.value = "A nova senha deve ter pelo menos 6 caracteres.";
    return;
  }
  if (passwords.value.next !== passwords.value.confirm) {
    passwordError.value = "As senhas não coincidem.";
    return;
  }

  savingPassword.value = true;
  try {
    await auth.updateProfile({
      current_password: passwords.value.current,
      password: passwords.value.next,
      password_confirmation: passwords.value.confirm,
    });
    passwords.value = { current: "", next: "", confirm: "" };
    passwordMsg.value = "Senha atualizada.";
  } catch (e) {
    const code = e.response?.data?.error;
    if (code === "invalid_current_password") {
      passwordError.value = "Senha atual incorreta.";
    } else if (code === "password_mismatch") {
      passwordError.value = "As senhas não coincidem.";
    } else {
      passwordError.value = e.response?.data?.details?.join(" ") || "Não foi possível alterar a senha.";
    }
  } finally {
    savingPassword.value = false;
  }
}
</script>

<template>
  <div class="container">
    <h1>Meu perfil</h1>
    <p class="muted">Atualize seus dados e, se quiser, troque a senha.</p>

    <div class="card" style="margin-top:1.2rem; max-width:480px">
      <h2>Dados pessoais</h2>
      <form class="form" @submit.prevent="saveProfile">
        <label>E-mail</label>
        <input :value="auth.user?.email" type="email" disabled />
        <label>Nome completo</label>
        <input v-model="profile.name" type="text" autocomplete="name" placeholder="Seu nome" />
        <label>Telefone</label>
        <input v-model="profile.phone" type="tel" autocomplete="tel" placeholder="(11) 99999-9999" />
        <p v-if="profileMsg" class="positive">{{ profileMsg }}</p>
        <p v-if="profileError" class="negative">{{ profileError }}</p>
        <button type="submit" :disabled="savingProfile">
          {{ savingProfile ? "Salvando…" : "Salvar dados" }}
        </button>
      </form>
    </div>

    <div class="card" style="margin-top:1.2rem; max-width:480px">
      <h2>Alterar senha</h2>
      <form class="form" @submit.prevent="savePassword">
        <label>Senha atual</label>
        <input v-model="passwords.current" type="password" autocomplete="current-password" required />
        <label>Nova senha</label>
        <input v-model="passwords.next" type="password" autocomplete="new-password" required minlength="6" />
        <label>Confirmar nova senha</label>
        <input v-model="passwords.confirm" type="password" autocomplete="new-password" required minlength="6" />
        <p v-if="passwordMsg" class="positive">{{ passwordMsg }}</p>
        <p v-if="passwordError" class="negative">{{ passwordError }}</p>
        <button type="submit" :disabled="savingPassword">
          {{ savingPassword ? "Salvando…" : "Alterar senha" }}
        </button>
      </form>
    </div>
  </div>
</template>

<style scoped>
h2 { margin: 0 0 0.8rem; font-size: 1.1rem; }
.form { display: flex; flex-direction: column; gap: 0.35rem; }
label { font-size: 0.85rem; color: var(--muted); margin-top: 0.45rem; }
input:disabled { background: #f5f1e8; color: var(--muted); }
button { margin-top: 1rem; align-self: flex-start; }
</style>
