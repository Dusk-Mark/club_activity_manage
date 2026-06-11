<script setup lang="ts">
import { RouterView } from 'vue-router'
import { isSupabaseConfigured, supabaseConfigMessage } from './lib/supabase'
</script>

<template>
  <div v-if="!isSupabaseConfigured" class="pointer-events-none fixed inset-x-4 top-4 z-50 flex justify-center">
    <div class="club-panel pointer-events-auto w-full max-w-4xl border border-[#e7d29c]/22 bg-[linear-gradient(180deg,rgba(52,40,18,0.88),rgba(18,16,12,0.96))] px-5 py-4 text-sm leading-6 text-[#f4e7c8] shadow-[0_24px_50px_-28px_rgba(0,0,0,0.72)]">
      {{ supabaseConfigMessage }}
    </div>
  </div>
  <RouterView />
</template>
