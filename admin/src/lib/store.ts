import { create } from "zustand";
import { persist } from "zustand/middleware";
import { authApi } from "./api";
import { getDeviceData } from "@/utils/device";

interface AuthState {
  token: string | null;
  user: { id: number; email: string; role: string } | null;
  setAuth: (token: string, user: { id: number; email: string; role: string }) => void;
  logout: () => Promise<void>;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      token: null,
      user: null,
      setAuth: (token, user) => set({ token, user }),
      // Di frontend: store.ts
logout: async () => {
  try {
    const device = getDeviceData();
    const currentUser = get().user;
    console.log("Data device yang dikirim logout:", device);

    if (currentUser && device.hardware_id) {

      await authApi.logout(device.hardware_id, currentUser.id);
      console.log("Backend sukses update is_active: false");
    }else{
      console.log("Data tidak lengkap logout (User/hardware_id kosong)")
    }
    
  } catch (err: any) {
    // Ini buat liat alasan spesifik dari NestJS (misal: "hardware_id must be a string")
    console.error("Detail Error 400 dari Backend:", err.response?.data);
  } finally {
    set({ token: null, user: null });
    localStorage.removeItem("access_token");
    window.location.href = "/login";
  }
},
    }),
    {
      name: "mangodefend-auth",
      onRehydrateStorage: () => (state) => {
        if (state?.token) {
          localStorage.setItem("access_token", state.token);
        }
      },
    }
  )
);
