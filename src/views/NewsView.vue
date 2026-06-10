<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { 
  ArrowLeft, 
  Newspaper, 
  Plus, 
  Calendar, 
  User, 
  Loader2,
  X,
  Send
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const posts = ref<any[]>([])
const loading = ref(true)
const showCreateModal = ref(false)
const publishing = ref(false)

const newPost = ref({
  title: '',
  content: '',
  type: 'news' as 'news' | 'announcement' | 'rule'
})

const fetchPosts = async () => {
  loading.value = true
  const { data } = await supabase
    .from('posts')
    .select('*, profiles(full_name)')
    .order('created_at', { ascending: false })
  
  posts.value = data || []
  loading.value = false
}

const handlePublish = async () => {
  if (!newPost.value.title || !newPost.value.content) return
  
  publishing.value = true
  try {
    const { error } = await supabase
      .from('posts')
      .insert({
        title: newPost.value.title,
        content: newPost.value.content,
        type: newPost.value.type,
        author_id: authStore.user?.id
      })
    
    if (error) throw error
    
    showCreateModal.value = false
    newPost.value = { title: '', content: '', type: 'news' }
    fetchPosts()
  } catch (error: any) {
    alert('发布失败: ' + error.message)
  } finally {
    publishing.value = false
  }
}

onMounted(() => {
  fetchPosts()
})
</script>

<template>
  <div class="min-h-screen bg-wanderlust p-4 lg:p-8">
    <div class="max-w-5xl mx-auto">
      <header class="flex items-center justify-between mb-8">
        <button @click="router.back()" class="flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:shadow-md transition-all font-bold text-slate-600">
          <ArrowLeft class="w-5 h-5" />
          返回
        </button>
        <h1 class="text-xl font-bold text-slate-900">新闻公告管理</h1>
        <button @click="showCreateModal = true" class="flex items-center gap-2 px-6 py-2.5 bg-primary text-white rounded-full font-bold shadow-lg shadow-primary/20 hover:scale-105 transition-all">
          <Plus class="w-5 h-5" />
          发布公告
        </button>
      </header>

      <main>
        <div v-if="loading" class="flex justify-center py-20">
          <Loader2 class="w-10 h-10 animate-spin text-primary" />
        </div>

        <div v-else-if="posts.length === 0" class="bg-white p-20 rounded-[3rem] shadow-xl text-center">
          <Newspaper class="w-16 h-16 text-slate-100 mx-auto mb-4" />
          <p class="text-slate-400 font-bold">暂无新闻公告</p>
        </div>

        <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div v-for="post in posts" :key="post.id" 
               class="bg-white p-8 rounded-[2.5rem] shadow-xl hover:shadow-2xl transition-all group border border-transparent hover:border-primary/10">
            <div class="flex items-center justify-between mb-4">
              <span :class="['px-3 py-1 text-[10px] font-bold rounded-full uppercase tracking-widest', 
                             post.type === 'news' ? 'bg-blue-50 text-blue-500' : 
                             post.type === 'announcement' ? 'bg-amber-50 text-amber-500' : 'bg-purple-50 text-purple-500']">
                {{ post.type === 'news' ? '校园新闻' : post.type === 'announcement' ? '重要通知' : '规章制度' }}
              </span>
              <span class="text-[10px] text-slate-400 font-bold uppercase tracking-widest flex items-center gap-1">
                <Calendar class="w-3 h-3" /> {{ new Date(post.created_at).toLocaleDateString() }}
              </span>
            </div>
            <h2 class="text-xl font-bold text-slate-800 mb-4 group-hover:text-primary transition-colors leading-tight">{{ post.title }}</h2>
            <p class="text-slate-500 text-sm line-clamp-3 mb-6 leading-relaxed">{{ post.content }}</p>
            <div class="flex items-center justify-between pt-6 border-t border-slate-50">
              <div class="flex items-center gap-2">
                <div class="w-6 h-6 rounded-full bg-slate-100 flex items-center justify-center">
                  <User class="w-3 h-3 text-slate-400" />
                </div>
                <span class="text-xs font-bold text-slate-600">{{ post.profiles?.full_name || '管理员' }}</span>
              </div>
              <button class="text-primary text-xs font-bold hover:underline">阅读详情</button>
            </div>
          </div>
        </div>
      </main>

      <!-- 发布弹窗 -->
      <div v-if="showCreateModal" class="fixed inset-0 z-[100] flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-slate-900/40 backdrop-blur-sm" @click="showCreateModal = false"></div>
        <div class="bg-white w-full max-w-lg rounded-[3rem] shadow-2xl relative z-10 overflow-hidden">
          <div class="p-8 lg:p-10">
            <div class="flex items-center justify-between mb-8">
              <h3 class="text-2xl font-bold text-slate-900">发布新闻公告</h3>
              <button @click="showCreateModal = false" class="p-2 hover:bg-slate-50 rounded-full transition-colors">
                <X class="w-6 h-6 text-slate-400" />
              </button>
            </div>

            <form @submit.prevent="handlePublish" class="space-y-6">
              <div class="space-y-2">
                <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">标题</label>
                <input v-model="newPost.title" type="text" placeholder="请输入标题..." 
                       class="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
              </div>

              <div class="space-y-2">
                <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">类型</label>
                <select v-model="newPost.type" 
                        class="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700 appearance-none">
                  <option value="news">校园新闻</option>
                  <option value="announcement">重要通知</option>
                  <option value="rule">规章制度</option>
                </select>
              </div>

              <div class="space-y-2">
                <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">内容</label>
                <textarea v-model="newPost.content" rows="5" placeholder="请输入正文内容..." 
                          class="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700 resize-none"></textarea>
              </div>

              <button :disabled="publishing" type="submit" 
                      class="w-full bg-slate-900 text-white py-5 rounded-[1.5rem] font-bold shadow-xl transition-all flex items-center justify-center gap-2 hover:bg-slate-800 disabled:opacity-50">
                <Loader2 v-if="publishing" class="w-5 h-5 animate-spin" />
                <template v-else>
                  <Send class="w-5 h-5" />
                  确认发布
                </template>
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
