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
  <div class="min-h-screen bg-wanderlust p-4 lg:p-8">
    <div class="max-w-4xl mx-auto">
      <header class="flex items-center justify-between mb-12">
        <button @click="router.back()" class="flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:shadow-md transition-all font-bold text-slate-600">
          <ArrowLeft class="w-5 h-5" />
          返回
        </button>
        <h1 class="text-xl font-bold text-slate-900">规章制度</h1>
        <div class="w-20"></div>
      </header>

      <main>
        <div class="mb-12 text-center">
          <div class="inline-flex p-4 bg-primary/10 rounded-[2rem] text-primary mb-4">
            <Scale class="w-10 h-10" />
          </div>
          <h2 class="text-3xl font-bold text-slate-900">校园社团行为准则</h2>
          <p class="text-slate-500 mt-2 font-medium">请各位同学及社团管理员严格遵守以下规定，共同维护和谐校园环境。</p>
        </div>

        <div v-if="loading" class="flex justify-center py-20">
          <Loader2 class="w-10 h-10 animate-spin text-primary" />
        </div>

        <div v-else class="space-y-6">
          <div v-for="rule in rules" :key="rule.id" 
               class="bg-white p-8 rounded-[2.5rem] shadow-xl hover:shadow-2xl transition-all group flex items-start gap-6">
            <div class="p-4 bg-slate-50 rounded-2xl text-slate-400 group-hover:bg-primary/10 group-hover:text-primary transition-colors">
              <ShieldAlert class="w-6 h-6" />
            </div>
            <div class="flex-1">
              <h3 class="text-xl font-bold text-slate-800 mb-3">{{ rule.title }}</h3>
              <p class="text-slate-500 leading-relaxed">{{ rule.content }}</p>
              <div class="mt-6 flex items-center gap-2 text-[10px] font-bold text-slate-300 uppercase tracking-widest">
                <span>发布于 {{ new Date(rule.created_at).toLocaleDateString() }}</span>
              </div>
            </div>
            <ChevronRight class="w-6 h-6 text-slate-200 self-center group-hover:text-primary transition-colors" />
          </div>

          <div v-if="rules.length === 0" class="bg-white p-12 rounded-[3rem] shadow-xl text-center text-slate-300">
            <BookOpen class="w-16 h-16 mx-auto mb-4" />
            <p class="font-bold">暂无规章制度发布</p>
          </div>
        </div>
      </main>
    </div>
  </div>
</template>
