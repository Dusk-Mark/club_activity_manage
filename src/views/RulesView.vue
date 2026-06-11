<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { 
  ArrowLeft, 
  BookOpen, 
  ShieldAlert, 
  Scale, 
  ChevronRight,
  Loader2
} from 'lucide-vue-next'

const router = useRouter()
const loading = ref(true)
const rules = ref<any[]>([])

const fetchRules = async () => {
  loading.value = true
  const { data } = await supabase
    .from('posts')
    .select('*')
    .eq('type', 'rule')
    .order('created_at', { ascending: false })
  
  rules.value = data || []
  loading.value = false
}

onMounted(() => {
  fetchRules()
})
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-5xl space-y-6">
      <header class="club-panel flex flex-col gap-4 px-5 py-5 md:flex-row md:items-center md:justify-between md:px-6">
        <div class="flex items-center gap-4">
          <button
            type="button"
            class="club-back-button flex h-12 w-12 items-center justify-center"
            @click="router.back()"
          >
            <ArrowLeft class="h-5 w-5" />
          </button>
          <div>
            <p class="text-sm text-slate-400">Rules Archive</p>
            <h1 class="font-display text-3xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>
        <span class="club-status-chip w-fit px-4 py-2 text-sm">校园治理规范</span>
      </header>

      <main class="space-y-6">
        <section class="club-panel p-8 text-center md:p-10">
          <div class="mx-auto flex h-18 w-18 items-center justify-center rounded-[28px] border border-[#d6bf8f]/16 bg-[#d6bf8f]/10 text-[#ecd7ad]">
            <Scale class="h-10 w-10" />
          </div>
          <h2 class="mt-5 font-display text-4xl font-bold text-white">校园社团行为准则</h2>
          <p class="mx-auto mt-3 max-w-2xl text-sm leading-7 text-slate-300 md:text-base">
            请各位同学及社团管理员遵守以下规定，共同维护校园活动秩序、组织声誉与协作环境。
          </p>
        </section>

        <div v-if="loading" class="club-panel flex justify-center py-20">
          <Loader2 class="h-10 w-10 animate-spin text-[#ecd7ad]" />
        </div>

        <div v-else class="space-y-5">
          <article
            v-for="rule in rules"
            :key="rule.id"
            class="card-hover club-panel flex flex-col gap-5 p-6 md:flex-row md:items-start md:p-7"
          >
            <div class="flex h-14 w-14 shrink-0 items-center justify-center rounded-[22px] border border-white/8 bg-white/5 text-[#ecd7ad]">
              <ShieldAlert class="h-6 w-6" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center justify-between gap-3">
                <h3 class="font-display text-3xl font-bold text-white">{{ rule.title }}</h3>
                <span class="text-xs text-slate-500">
                  发布于 {{ new Date(rule.created_at).toLocaleDateString() }}
                </span>
              </div>
              <p class="mt-4 text-sm leading-8 text-slate-300">{{ rule.content }}</p>
            </div>
            <ChevronRight class="hidden h-5 w-5 shrink-0 text-slate-500 md:block" />
          </article>

          <div v-if="rules.length === 0" class="club-empty-state p-16 text-slate-300">
            <BookOpen class="mx-auto h-16 w-16 text-slate-500" />
            <p class="mt-4 font-display text-3xl font-bold text-white">暂无规章制度发布</p>
          </div>
        </div>
      </main>
    </div>
  </div>
</template>
