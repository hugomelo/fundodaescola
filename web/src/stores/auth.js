import { defineStore } from "pinia";
import client from "../api/client";

export const useAuthStore = defineStore("auth", {
  state: () => ({
    token: localStorage.getItem("cc_token") || null,
    user: null,
    loading: false,
  }),
  getters: {
    isAuthenticated: (s) => !!s.token,
    isAdmin: (s) => s.user && (s.user.role === "super_admin" || s.user.role === "grade_admin"),
    isSuperAdmin: (s) => s.user && s.user.role === "super_admin",
    isParent: (s) => s.user && s.user.role === "parent",
    students: (s) => (s.user && s.user.students) || [],
  },
  actions: {
    async login(email, password) {
      const { data } = await client.post("/auth/login", { email, password });
      this.token = data.token;
      this.user = data.user;
      localStorage.setItem("cc_token", data.token);
      return data.user;
    },
    async fetchMe() {
      if (!this.token) return null;
      this.loading = true;
      try {
        const { data } = await client.get("/me");
        this.user = data.user;
        return data.user;
      } finally {
        this.loading = false;
      }
    },
    logout() {
      this.token = null;
      this.user = null;
      localStorage.removeItem("cc_token");
    },
  },
});
