import { defineStore } from "pinia";
import client from "../api/client";
import { useAdminStore } from "./admin";

export const useAuthStore = defineStore("auth", {
  state: () => ({
    token: localStorage.getItem("cc_token") || null,
    user: null,
    loading: false,
    selectedStudentId: Number(localStorage.getItem("cc_parent_student")) || null,
  }),
  getters: {
    isAuthenticated: (s) => !!s.token,
    isAdmin: (s) => s.user && (s.user.role === "super_admin" || s.user.role === "grade_admin"),
    isSuperAdmin: (s) => s.user && s.user.role === "super_admin",
    isParent: (s) => s.user && s.user.role === "parent",
    students: (s) => (s.user && s.user.students) || [],
    selectedStudent(s) {
      const list = (s.user && s.user.students) || [];
      if (!list.length) return null;
      return list.find((st) => st.id === Number(s.selectedStudentId)) || list[0];
    },
  },
  actions: {
    async login(email, password) {
      const { data } = await client.post("/auth/login", { email, password });
      this.token = data.token;
      this.user = data.user;
      localStorage.setItem("cc_token", data.token);
      useAdminStore().reset();
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
    async updateProfile(attrs) {
      const { data } = await client.patch("/me", { user: attrs });
      this.user = data.user;
      return data.user;
    },
    selectStudent(id) {
      const numeric = Number(id);
      if (!this.students.some((s) => s.id === numeric)) return;
      this.selectedStudentId = numeric;
      localStorage.setItem("cc_parent_student", String(numeric));
    },
    logout() {
      this.token = null;
      this.user = null;
      this.selectedStudentId = null;
      localStorage.removeItem("cc_token");
      localStorage.removeItem("cc_parent_student");
      useAdminStore().reset();
    },
  },
});
