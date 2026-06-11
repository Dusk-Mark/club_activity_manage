<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { 
  ArrowLeft, 
  Search, 
  ChevronRight, 
  Trophy
} from 'lucide-vue-next'

const router = useRouter()
const loading = ref(true)
const clubs = ref<any[]>([])
const searchQuery = ref('')
const selectedCategory = ref('全部')

const categories = ['全部', '学术科技', '体育竞技', '文化艺术', '志愿服务', '其他']

const fetchClubs = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('clubs')
      .select('*, club_members(id)')
      .eq('status', 'active')
    
    if (error) throw error
    clubs.value = data?.map(club => ({
      ...club,
      memberCount: club.club_members?.length || 0
    })) || []
  } catch (error: any) {
    console.error('Error fetching clubs:', error.message)
  } finally {
    loading.value = false
  }
}

const filteredClubs = computed(() => {
  return clubs.value.filter(club => {
    const matchesSearch = club.name.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
                         club.description?.toLowerCase().includes(searchQuery.value.toLowerCase())
    return matchesSearch
  })
})

onMounted(() => {
  fetchClubs()
})
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-7xl space-y-6">
      <header class="club-panel flex flex-col gap-5 px-5 py-5 md:px-6 xl:flex-row xl:items-end xl:justify-between">
        <div class="space-y-4">
          <button
            type="button"
            class="club-back-button inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold"
            @click="router.back()"
          >
            <ArrowLeft class="h-4 w-4" />
            返回
          </button>
          <div>
            <p class="text-sm text-slate-400">Club Directory</p>
            <h1 class="font-display text-4xl font-bold text-white md:text-5xl">中北大学社团活动</h1>
          </div>
          <p class="max-w-2xl text-sm leading-7 text-slate-300 md:text-base">
            浏览校园里的兴趣共同体，查看简介、成员规模与近期动向，并快速进入对应社团主页。
          </p>
        </div>

        <div class="grid gap-3 sm:grid-cols-3 xl:min-w-[380px]">
          <article class="club-panel-muted p-4">
            <p class="text-sm text-slate-400">社团总数</p>
            <p class="mt-2 text-2xl font-semibold text-white">{{ clubs.length }}</p>
          </article>
          <article class="club-panel-muted p-4">
            <p class="text-sm text-slate-400">筛选分类</p>
            <p class="mt-2 text-2xl font-semibold text-white">{{ categories.length }}</p>
          </article>
          <article class="club-panel-muted p-4">
            <p class="text-sm text-slate-400">当前视图</p>
            <p class="mt-2 text-lg font-semibold text-white">{{ selectedCategory }}</p>
          </article>
        </div>
      </header>

      <main class="space-y-6">
        <section class="club-panel p-5 md:p-6">
          <div class="flex flex-col gap-4 xl:flex-row xl:items-center">
            <div class="relative flex-1">
              <Search class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
              <input
                v-model="searchQuery"
                type="text"
                placeholder="输入关键词搜索社团..."
                class="club-input w-full py-4 pl-12 pr-4"
              />
            </div>

            <div class="flex w-full items-center gap-2 overflow-x-auto pb-2 xl:w-auto xl:pb-0 no-scrollbar">
              <button
                v-for="cat in categories"
                :key="cat"
                type="button"
                @click="selectedCategory = cat"
                :class="[
                  'whitespace-nowrap rounded-2xl px-5 py-3 text-sm font-semibold transition-all',
                  selectedCategory === cat ? 'club-button-primary' : 'club-button-secondary'
                ]"
              >
                {{ cat }}
              </button>
            </div>
          </div>
        </section>

        <div v-if="loading" class="grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-3">
          <div v-for="i in 6" :key="i" class="club-panel-muted shimmer-block h-72 rounded-[28px]" />
        </div>

        <div v-else class="grid grid-cols-1 gap-6 md:grid-cols-2 xl:grid-cols-3">
          <button
            v-for="club in filteredClubs"
            :key="club.id"
            type="button"
            class="group card-hover club-panel overflow-hidden p-2 text-left"
            @click="router.push(`/club/${club.id}`)"
          >
            <div class="relative overflow-hidden rounded-[24px]">
              <img
                :src="club.logo_url || `https://picsum.photos/seed/${encodeURIComponent(club.name)}/960/720`"
                :alt="club.name"
                class="h-56 w-full object-cover transition-transform duration-500 group-hover:scale-105"
              />
              <div class="absolute inset-0 bg-gradient-to-t from-[#060807] via-[#060807]/18 to-transparent" />
              <div class="absolute left-5 top-5">
                <span class="club-pill px-3 py-1 text-xs">社团名录</span>
              </div>
              <div class="absolute bottom-5 left-5 right-5 flex items-end justify-between gap-4">
                <div class="min-w-0">
                  <p class="text-xs uppercase tracking-[0.18em] text-white/60">Campus Club</p>
                  <h3 class="truncate font-display text-3xl font-bold text-white">{{ club.name }}</h3>
                </div>
                <div class="rounded-2xl border border-white/10 bg-black/25 p-3 text-white backdrop-blur-md">
                  <ChevronRight class="h-5 w-5" />
                </div>
              </div>
            </div>

            <div class="grid gap-4 p-5">
              <div class="flex items-center justify-between gap-3">
                <div class="flex items-center gap-2 text-[#ecd7ad]">
                  <Trophy class="h-4 w-4" />
                  <span class="text-sm font-medium">推荐组织</span>
                </div>
                <span class="text-sm text-slate-400">{{ club.memberCount }} 名成员</span>
              </div>
              <p class="line-clamp-3 text-sm leading-7 text-slate-300">
                {{ club.description || '暂无社团简介。' }}
              </p>
            </div>
          </button>
        </div>

        <div v-if="!loading && filteredClubs.length === 0" class="club-empty-state p-16">
          <Search class="mx-auto h-14 w-14 text-slate-500" />
          <p class="mt-4 font-display text-3xl font-bold text-white">未找到相关社团</p>
          <p class="mt-2 text-sm text-slate-400">换一个关键词试试，或者重置筛选条件后重新浏览。</p>
          <button
            type="button"
            class="club-button-primary mt-6 rounded-2xl px-5 py-3 text-sm font-semibold"
            @click="searchQuery = ''; selectedCategory = '全部'"
          >
            重置搜索
          </button>
        </div>
      </main>
    </div>
  </div>
</template>

<style scoped>
.no-scrollbar::-webkit-scrollbar {
  display: none;
}
.no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>
