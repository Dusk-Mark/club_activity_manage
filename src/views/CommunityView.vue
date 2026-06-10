<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import {
  ArrowLeft,
  Bell,
  Loader2,
  MessageCircleMore,
  Newspaper,
  Send,
  Users
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()

const loading = ref(true)
const sending = ref(false)
const activeTarget = ref<'global' | 'club' | 'activity'>('global')
const posts = ref<any[]>([])
const messages = ref<any[]>([])
const clubs = ref<any[]>([])
const activities = ref<any[]>([])
const form = ref({
  targetId: '',
  content: ''
})
const message = ref({ text: '', type: '' })

const scopedTargets = computed(() => {
  if (activeTarget.value === 'club') {
    return clubs.value
  }

  if (activeTarget.value === 'activity') {
    return activities.value
  }

  return []
})

const filteredMessages = computed(() => {
  if (activeTarget.value === 'global') {
    return messages.value.filter(item => item.target_type === 'global')
  }

  return messages.value.filter(item => {
    return item.target_type === activeTarget.value && item.target_id === form.value.targetId
  })
})

const fetchData = async () => {
  loading.value = true

  try {
    await authStore.ensureUser()

    const [
      { data: postData, error: postError },
      { data: messageData, error: messageError },
      { data: clubData, error: clubError },
      { data: activityData, error: activityError }
    ] = await Promise.all([
      supabase
        .from('posts')
        .select('id, title, content, type, created_at')
        .in('type', ['announcement', 'news'])
        .order('created_at', { ascending: false })
        .limit(6),
      supabase
        .from('messages')
        .select('*, profiles(full_name, avatar_url)')
        .order('created_at', { ascending: false })
        .limit(40),
      supabase
        .from('clubs')
        .select('id, name')
        .order('created_at', { ascending: false })
        .limit(12),
      supabase
        .from('activities')
        .select('id, title, club_id, clubs(name)')
        .order('start_time', { ascending: false })
        .limit(12)
    ])

    if (postError) throw postError
    if (messageError) throw messageError
    if (clubError) throw clubError
    if (activityError) throw activityError

    posts.value = postData || []
    messages.value = messageData || []
    clubs.value = clubData || []
    activities.value = activityData || []

    if (!form.value.targetId && activeTarget.value === 'club' && clubs.value.length) {
      form.value.targetId = clubs.value[0].id
    }

    if (!form.value.targetId && activeTarget.value === 'activity' && activities.value.length) {
      form.value.targetId = activities.value[0].id
    }
  } catch (error) {
    message.value = { text: '互动社区加载失败，请稍后刷新。', type: 'error' }
    console.error('Error fetching community data:', error)
  } finally {
    loading.value = false
  }
}

const switchTarget = (target: 'global' | 'club' | 'activity') => {
  activeTarget.value = target
  form.value.targetId = ''

  if (target === 'club' && clubs.value.length) {
    form.value.targetId = clubs.value[0].id
  }

  if (target === 'activity' && activities.value.length) {
    form.value.targetId = activities.value[0].id
  }
}

const handleSend = async () => {
  if (!authStore.user) {
    router.push('/')
    return
  }

  if (!form.value.content.trim()) {
    message.value = { text: '请输入交流内容。', type: 'error' }
    return
  }

  if (activeTarget.value !== 'global' && !form.value.targetId) {
    message.value = { text: '请选择留言目标。', type: 'error' }
    return
  }

  sending.value = true
  message.value = { text: '', type: '' }

  try {
    const { error } = await supabase
      .from('messages')
      .insert({
        sender_id: authStore.user.id,
        content: form.value.content.trim(),
        target_type: activeTarget.value,
        target_id: activeTarget.value === 'global' ? null : form.value.targetId
      })

    if (error) throw error

    form.value.content = ''
    message.value = { text: '留言已发布。', type: 'success' }
    await fetchData()
  } catch (error: any) {
    message.value = { text: error.message || '发送失败，请稍后重试。', type: 'error' }
  } finally {
    sending.value = false
  }
}

onMounted(() => {
  fetchData()
})
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-7xl space-y-6">
      <header class="club-panel flex flex-col gap-4 px-5 py-5 md:px-6 xl:flex-row xl:items-center xl:justify-between">
        <div class="flex items-center gap-4">
          <button
            type="button"
            class="flex h-12 w-12 items-center justify-center rounded-2xl border border-white/8 bg-white/5 text-slate-200"
            @click="router.back()"
          >
            <ArrowLeft class="h-5 w-5" />
          </button>
          <div>
            <p class="text-sm text-slate-400">Community</p>
            <h1 class="font-display text-3xl font-bold text-white">互动交流中心</h1>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3 text-sm text-slate-300">
          <span class="club-pill px-4 py-2">留言板</span>
          <span class="rounded-full border border-white/8 px-4 py-2">互动社区</span>
          <span class="rounded-full border border-white/8 px-4 py-2">公告联动</span>
        </div>
      </header>

      <div class="grid gap-6 xl:grid-cols-[1.06fr_0.94fr]">
        <section class="club-panel p-6 md:p-8">
          <div class="mb-6 flex flex-wrap items-center gap-3">
            <button
              type="button"
              class="rounded-2xl px-4 py-3 text-sm font-semibold"
              :class="activeTarget === 'global' ? 'club-button-primary' : 'club-button-secondary'"
              @click="switchTarget('global')"
            >
              全校留言
            </button>
            <button
              type="button"
              class="rounded-2xl px-4 py-3 text-sm font-semibold"
              :class="activeTarget === 'club' ? 'club-button-primary' : 'club-button-secondary'"
              @click="switchTarget('club')"
            >
              社团留言
            </button>
            <button
              type="button"
              class="rounded-2xl px-4 py-3 text-sm font-semibold"
              :class="activeTarget === 'activity' ? 'club-button-primary' : 'club-button-secondary'"
              @click="switchTarget('activity')"
            >
              活动留言
            </button>
          </div>

          <div class="mb-5 grid gap-4 md:grid-cols-3">
            <article class="club-panel-muted p-5">
              <Users class="h-5 w-5 text-[#f2ddae]" />
              <p class="mt-3 font-display text-2xl font-bold text-white">{{ clubs.length }}</p>
              <p class="mt-2 text-sm text-slate-400">社团讨论范围</p>
            </article>
            <article class="club-panel-muted p-5">
              <Bell class="h-5 w-5 text-[#9fc0f7]" />
              <p class="mt-3 font-display text-2xl font-bold text-white">{{ posts.length }}</p>
              <p class="mt-2 text-sm text-slate-400">公告与新闻</p>
            </article>
            <article class="club-panel-muted p-5">
              <MessageCircleMore class="h-5 w-5 text-emerald-300" />
              <p class="mt-3 font-display text-2xl font-bold text-white">{{ messages.length }}</p>
              <p class="mt-2 text-sm text-slate-400">最新互动消息</p>
            </article>
          </div>

          <div v-if="message.text" class="mb-5 rounded-2xl border px-4 py-3 text-sm leading-6" :class="message.type === 'success'
            ? 'border-emerald-400/18 bg-emerald-400/10 text-emerald-100'
            : 'border-rose-400/18 bg-rose-400/10 text-rose-100'">
            {{ message.text }}
          </div>

          <div v-if="activeTarget !== 'global'" class="mb-4">
            <select v-model="form.targetId" class="club-input w-full px-4 py-4">
              <option value="">请选择目标</option>
              <option v-for="item in scopedTargets" :key="item.id" :value="item.id">
                {{ item.name || item.title }}
              </option>
            </select>
          </div>

          <div class="club-panel-muted rounded-[24px] p-4">
            <textarea
              v-model="form.content"
              rows="4"
              class="club-input w-full resize-none px-4 py-4"
              placeholder="分享活动建议、社团想法或现场反馈..."
            />
            <div class="mt-4 flex justify-end">
              <button
                type="button"
                :disabled="sending || loading"
                class="club-button-primary flex items-center gap-2 rounded-2xl px-5 py-3 text-sm font-semibold disabled:opacity-60"
                @click="handleSend"
              >
                <Loader2 v-if="sending" class="h-4 w-4 animate-spin" />
                <template v-else>
                  <Send class="h-4 w-4" />
                  发布留言
                </template>
              </button>
            </div>
          </div>

          <div class="mt-6">
            <div class="mb-4 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Live Feed</p>
                <h3 class="mt-1 font-display text-2xl font-bold text-white">社区动态</h3>
              </div>
              <button class="text-sm font-medium text-[#9fc0f7]" @click="router.push('/news')">
                查看公告
              </button>
            </div>

            <div v-if="loading" class="flex justify-center py-16">
              <Loader2 class="h-8 w-8 animate-spin text-[#f2ddae]" />
            </div>

            <div v-else-if="filteredMessages.length" class="space-y-4">
              <article
                v-for="item in filteredMessages"
                :key="item.id"
                class="card-hover club-panel-muted rounded-[24px] p-5"
              >
                <div class="flex items-start gap-4">
                  <div class="h-12 w-12 overflow-hidden rounded-2xl border border-white/8 bg-white/5">
                    <img
                      :src="item.profiles?.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(item.profiles?.full_name || '用户')}&background=1f2937&color=ffffff`"
                      :alt="item.profiles?.full_name || '用户'"
                      class="h-full w-full object-cover"
                    />
                  </div>
                  <div class="min-w-0 flex-1">
                    <div class="flex flex-wrap items-center gap-3">
                      <p class="font-semibold text-white">{{ item.profiles?.full_name || '校园用户' }}</p>
                      <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                        {{ new Date(item.created_at).toLocaleString('zh-CN') }}
                      </span>
                    </div>
                    <p class="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-300">{{ item.content }}</p>
                  </div>
                </div>
              </article>
            </div>

            <div
              v-else
              class="club-panel-muted flex min-h-56 flex-col items-center justify-center rounded-[24px] p-8 text-center"
            >
              <MessageCircleMore class="h-8 w-8 text-slate-500" />
              <p class="mt-4 font-display text-2xl font-bold text-white">当前范围还没有留言</p>
              <p class="mt-2 max-w-md text-sm leading-6 text-slate-400">
                你可以先发布一条讨论内容，让社团和活动交流逐渐沉淀起来。
              </p>
            </div>
          </div>
        </section>

        <aside class="space-y-6">
          <section class="club-panel p-6 md:p-8">
            <div class="mb-5 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Announcement Feed</p>
                <h3 class="mt-1 font-display text-2xl font-bold text-white">系统公告</h3>
              </div>
              <Newspaper class="h-5 w-5 text-[#f2ddae]" />
            </div>

            <div v-if="loading" class="flex justify-center py-16">
              <Loader2 class="h-8 w-8 animate-spin text-[#f2ddae]" />
            </div>

            <div v-else-if="posts.length" class="space-y-4">
              <article
                v-for="post in posts"
                :key="post.id"
                class="card-hover club-panel-muted rounded-[24px] p-5"
              >
                <div class="flex items-center justify-between gap-3">
                  <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                    {{ post.type === 'announcement' ? '重要通知' : '校园新闻' }}
                  </span>
                  <span class="text-xs text-slate-500">{{ new Date(post.created_at).toLocaleDateString('zh-CN') }}</span>
                </div>
                <h4 class="mt-4 text-lg font-semibold text-white">{{ post.title }}</h4>
                <p class="mt-3 line-clamp-3 text-sm leading-6 text-slate-300">{{ post.content }}</p>
              </article>
            </div>

            <div
              v-else
              class="club-panel-muted flex min-h-48 flex-col items-center justify-center rounded-[24px] p-8 text-center"
            >
              <Bell class="h-8 w-8 text-slate-500" />
              <p class="mt-4 font-display text-2xl font-bold text-white">暂无系统公告</p>
              <p class="mt-2 text-sm leading-6 text-slate-400">后续发布的通知和新闻会在这里同步展示。</p>
            </div>
          </section>

          <section class="club-panel p-6 md:p-8">
            <p class="text-sm text-slate-400">使用建议</p>
            <div class="mt-4 space-y-3 text-sm leading-7 text-slate-300">
              <p>全校留言适合收集建议、答疑和公开讨论。</p>
              <p>社团留言适合沉淀招新交流、内部通知和成员协作。</p>
              <p>活动留言适合做现场互动、签到提醒和活动反馈补充。</p>
            </div>
          </section>
        </aside>
      </div>
    </div>
  </div>
</template>
