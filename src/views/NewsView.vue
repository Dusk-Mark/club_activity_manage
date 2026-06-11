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
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-6xl space-y-6">
      <header class="club-panel flex flex-col gap-4 px-5 py-5 md:flex-row md:items-end md:justify-between md:px-6">
        <div class="space-y-3">
          <button
            type="button"
            class="club-back-button inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold"
            @click="router.back()"
          >
            <ArrowLeft class="h-4 w-4" />
            返回
          </button>
          <div>
            <p class="text-sm text-slate-400">Newsroom</p>
            <h1 class="font-display text-4xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>

        <button
          type="button"
          class="club-button-primary flex w-fit items-center gap-2 rounded-2xl px-5 py-3 text-sm font-semibold"
          @click="showCreateModal = true"
        >
          <Plus class="h-4 w-4" />
          发布公告
        </button>
      </header>

      <main>
        <div v-if="loading" class="club-panel flex justify-center py-20">
          <Loader2 class="h-10 w-10 animate-spin text-[#ecd7ad]" />
        </div>

        <div v-else-if="posts.length === 0" class="club-empty-state p-20">
          <Newspaper class="mx-auto h-16 w-16 text-slate-500" />
          <p class="mt-4 font-display text-3xl font-bold text-white">暂无新闻公告</p>
          <p class="mt-2 text-sm text-slate-400">新发布的校园新闻、通知与规章会在这里统一展示。</p>
        </div>

        <div v-else class="grid grid-cols-1 gap-6 md:grid-cols-2">
          <article
            v-for="post in posts"
            :key="post.id"
            class="card-hover club-panel p-6 md:p-7"
          >
            <div class="flex items-center justify-between gap-3">
              <span
                :class="[
                  'rounded-full border px-3 py-1 text-xs',
                  post.type === 'news'
                    ? 'border-[#6d8d7d]/20 bg-[#6d8d7d]/10 text-[#d9e7de]'
                    : post.type === 'announcement'
                      ? 'border-[#d6bf8f]/20 bg-[#d6bf8f]/10 text-[#ecd7ad]'
                      : 'border-white/10 bg-white/5 text-slate-300'
                ]"
              >
                {{ post.type === 'news' ? '校园新闻' : post.type === 'announcement' ? '重要通知' : '规章制度' }}
              </span>
              <span class="flex items-center gap-1 text-xs text-slate-500">
                <Calendar class="h-3 w-3" />
                {{ new Date(post.created_at).toLocaleDateString() }}
              </span>
            </div>

            <h2 class="mt-5 font-display text-3xl font-bold leading-tight text-white">
              {{ post.title }}
            </h2>
            <p class="mt-4 line-clamp-4 text-sm leading-7 text-slate-300">{{ post.content }}</p>

            <div class="club-divider my-5" />

            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-3">
                <div class="flex h-9 w-9 items-center justify-center rounded-2xl border border-white/8 bg-white/5">
                  <User class="h-4 w-4 text-slate-400" />
                </div>
                <span class="text-sm text-slate-300">{{ post.profiles?.full_name || '管理员' }}</span>
              </div>
              <button type="button" class="text-sm font-medium text-[#ecd7ad]">阅读详情</button>
            </div>
          </article>
        </div>
      </main>

      <div v-if="showCreateModal" class="fixed inset-0 z-[100] flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-md" @click="showCreateModal = false"></div>
        <div class="club-panel relative z-10 w-full max-w-xl p-7 md:p-8">
          <div class="mb-6 flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-400">New Post</p>
              <h3 class="mt-1 font-display text-3xl font-bold text-white">发布新闻公告</h3>
            </div>
            <button
              type="button"
              class="club-back-button flex h-11 w-11 items-center justify-center"
              @click="showCreateModal = false"
            >
              <X class="h-5 w-5" />
            </button>
          </div>

          <form @submit.prevent="handlePublish" class="space-y-5">
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">标题</label>
              <input
                v-model="newPost.title"
                type="text"
                placeholder="请输入标题..."
                class="club-input w-full px-5 py-4"
              />
            </div>

            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">类型</label>
              <select v-model="newPost.type" class="club-input w-full px-5 py-4">
                <option value="news">校园新闻</option>
                <option value="announcement">重要通知</option>
                <option value="rule">规章制度</option>
              </select>
            </div>

            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">内容</label>
              <textarea
                v-model="newPost.content"
                rows="6"
                placeholder="请输入正文内容..."
                class="club-input w-full resize-none px-5 py-4"
              ></textarea>
            </div>

            <button
              :disabled="publishing"
              type="submit"
              class="club-button-primary flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-base font-semibold disabled:opacity-60"
            >
              <Loader2 v-if="publishing" class="h-5 w-5 animate-spin" />
              <template v-else>
                <Send class="h-5 w-5" />
                确认发布
              </template>
            </button>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>
