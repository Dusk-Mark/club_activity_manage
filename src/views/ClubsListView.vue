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
  <div class="min-h-screen bg-wanderlust p-4 lg:p-8">
    <div class="max-w-6xl mx-auto">
      <!-- 头部 -->
      <header class="flex items-center justify-between mb-8">
        <button @click="router.back()" class="flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:shadow-md transition-all font-bold text-slate-600">
          <ArrowLeft class="w-5 h-5" />
          返回
        </button>
        <h1 class="text-xl font-bold text-slate-900">探索社团</h1>
        <div class="w-20"></div>
      </header>

      <main class="space-y-8">
        <!-- 搜索与筛选 -->
        <section class="bg-white p-6 rounded-[2.5rem] shadow-xl flex flex-col md:flex-row gap-4 items-center">
          <div class="flex-1 flex items-center gap-3 bg-slate-50 p-3 rounded-2xl border border-slate-100 w-full">
            <Search class="w-5 h-5 text-slate-300 ml-2" />
            <input v-model="searchQuery" type="text" placeholder="输入关键词搜索社团..." class="bg-transparent border-none outline-none flex-1 font-bold text-slate-700" />
          </div>
          
          <div class="flex items-center gap-2 overflow-x-auto pb-2 md:pb-0 w-full md:w-auto no-scrollbar">
            <button v-for="cat in categories" :key="cat"
                    @click="selectedCategory = cat"
                    :class="['px-5 py-2.5 rounded-xl font-bold text-sm transition-all whitespace-nowrap', 
                             selectedCategory === cat ? 'bg-primary text-white shadow-lg shadow-primary/20' : 'bg-slate-50 text-slate-400 hover:bg-slate-100']">
              {{ cat }}
            </button>
          </div>
        </section>

        <!-- 社团网格 -->
        <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div v-for="i in 6" :key="i" class="bg-white p-6 rounded-[2.5rem] shadow-lg animate-pulse h-48"></div>
        </div>

        <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div v-for="club in filteredClubs" :key="club.id" 
               @click="router.push(`/club/${club.id}`)"
               class="bg-white p-8 rounded-[3rem] shadow-xl hover:shadow-2xl transition-all group border border-transparent hover:border-primary/10 flex flex-col cursor-pointer">
            <div class="flex items-start justify-between mb-6">
              <div class="w-20 h-20 rounded-[2rem] bg-slate-50 overflow-hidden shadow-inner border border-slate-100 p-1">
                <img :src="club.logo_url || `https://ui-avatars.com/api/?name=${club.name}&background=random&size=128`" class="w-full h-full object-cover rounded-[1.8rem]" />
              </div>
              <div class="flex items-center gap-1 text-amber-500 bg-amber-50 px-3 py-1 rounded-full">
                <Trophy class="w-3.5 h-3.5 fill-amber-500" />
                <span class="text-[10px] font-bold uppercase tracking-widest">推荐</span>
              </div>
            </div>

            <div class="flex-1">
              <h3 class="text-2xl font-bold text-slate-900 mb-2 group-hover:text-primary transition-colors">{{ club.name }}</h3>
              <p class="text-slate-400 text-sm font-medium line-clamp-2 mb-6 leading-relaxed">{{ club.description || '暂无社团简介。' }}</p>
            </div>

            <div class="flex items-center justify-between pt-6 border-t border-slate-50">
              <div class="flex items-center gap-2">
                <div class="flex -space-x-2">
                  <div v-for="i in 3" :key="i" class="w-6 h-6 rounded-full border-2 border-white bg-slate-200"></div>
                </div>
                <span class="text-xs font-bold text-slate-400">{{ club.memberCount }} 名成员</span>
              </div>
              <button class="p-3 bg-slate-900 text-white rounded-2xl hover:bg-primary transition-all shadow-lg shadow-slate-900/10">
                <ChevronRight class="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>

        <!-- 空状态 -->
        <div v-if="!loading && filteredClubs.length === 0" class="bg-white p-20 rounded-[3rem] shadow-xl text-center">
          <Search class="w-16 h-16 text-slate-100 mx-auto mb-4" />
          <p class="text-slate-400 font-bold text-xl">未找到相关社团</p>
          <button @click="searchQuery = ''; selectedCategory = '全部'" class="mt-4 text-primary font-bold hover:underline">重置搜索</button>
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
