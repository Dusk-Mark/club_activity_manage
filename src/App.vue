<script setup lang="ts">
import { RouterView } from 'vue-router'
import { isSupabaseConfigured, supabaseConfigMessage } from './lib/supabase'
</script>

<template>
  <div v-if="!isSupabaseConfigured" class="mx-4 mt-4 rounded-2xl border border-amber-400/20 bg-amber-400/10 px-4 py-3 text-sm text-amber-100">
    {{ supabaseConfigMessage }}
  </div>
  <RouterView />
</template>
