<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { 
  ArrowLeft, 
  Users, 
  Search, 
  Trash2, 
  Loader2,
  ShieldCheck,
  User,
  MoreVertical
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const loading = ref(true)
const members = ref<any[]>([])
const myClubs = ref<any[]>([])
const selectedClubId = ref<string | null>(null)
const searchQuery = ref('')

const fetchMyClubs = async () => {
  if (!authStore.user) return
  const { data } = await supabase
    .from('club_members')
    .select('club_id, clubs(id, name)')
    .eq('user_id', authStore.user.id)
    .eq('role', 'admin')
  
  myClubs.value = data?.map(item => item.clubs) || []
  if (myClubs.value.length > 0) {
    selectedClubId.value = myClubs.value[0].id
    fetchMembers()
  } else {
    loading.value = false
  }
}

const fetchMembers = async () => {
  if (!selectedClubId.value) return
  loading.value = true
  
  const { data } = await supabase
    .from('club_members')
    .select('*, profiles(full_name, avatar_url, username)')
    .eq('club_id', selectedClubId.value)
  
  members.value = data || []
  loading.value = false
}

const handleRemoveMember = async (userId: string) => {
  if (!confirm('确定要移除该成员吗？')) return
  
  try {
    const { error } = await supabase
      .from('club_members')
      .delete()
      .eq('club_id', selectedClubId.value)
      .eq('user_id', userId)
    
    if (error) throw error
    members.value = members.value.filter(m => m.user_id !== userId)
  } catch (error: any) {
    alert('操作失败: ' + error.message)
  }
}

onMounted(async () => {
  await authStore.ensureUser()
  fetchMyClubs()
})

const filteredMembers = () => {
  if (!searchQuery.value) return members.value
  return members.value.filter(m => 
    m.profiles?.full_name?.includes(searchQuery.value) || 
    m.profiles?.username?.includes(searchQuery.value)
  )
}
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-7xl space-y-6">
      <header class="club-panel flex flex-col gap-4 px-5 py-5 md:flex-row md:items-center md:justify-between md:px-6">
        <div class="flex items-center gap-4">
          <button
            type="button"
            class="club-back-button flex h-12 w-12 items-center justify-center"
            @click="router.back()"
          >
            <ArrowLeft class="h-5 w-5" />
          </button>
          <div class="flex h-12 w-12 items-center justify-center overflow-hidden rounded-2xl border border-white/10 bg-white/92 p-1 shadow-[0_16px_28px_-18px_rgba(0,0,0,0.45)]">
            <img src="/%E4%B8%AD%E5%8C%97%E5%A4%A7%E5%AD%A6%E6%A0%A1%E5%BE%BD.png" alt="中北大学校徽" class="h-full w-full object-contain" />
          </div>
          <div>
            <p class="text-sm text-slate-400">Member Registry</p>
            <h1 class="font-display text-3xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>
        <span class="club-status-chip w-fit px-4 py-2 text-sm">组织成员维护</span>
      </header>

      <div v-if="myClubs.length === 0 && !loading" class="club-empty-state p-12">
        <Users class="mx-auto h-16 w-16 text-slate-500" />
        <h2 class="mt-4 font-display text-3xl font-bold text-white">您还没有管理的社团</h2>
        <button
          type="button"
          class="club-button-primary mt-6 rounded-2xl px-8 py-3 text-sm font-semibold"
          @click="router.push('/create-club')"
        >
          创建社团
        </button>
      </div>

      <div v-else class="grid grid-cols-1 gap-6 lg:grid-cols-[0.34fr_0.66fr]">
        <aside class="space-y-4">
          <section class="club-panel p-5 md:p-6">
            <p class="text-sm text-slate-400">Managed Clubs</p>
            <h3 class="mt-1 font-display text-3xl font-bold text-white">管理的社团</h3>
            <div class="mt-5 space-y-3">
              <button
                v-for="club in myClubs"
                :key="club.id"
                type="button"
                @click="selectedClubId = club.id; fetchMembers()"
                :class="[
                  'w-full rounded-2xl p-4 text-left text-sm font-semibold transition-all',
                  selectedClubId === club.id ? 'club-button-primary' : 'club-button-secondary'
                ]"
              >
                <span class="flex items-center gap-3">
                  <ShieldCheck class="h-4 w-4" />
                  <span class="truncate">{{ club.name }}</span>
                </span>
              </button>
            </div>
          </section>
        </aside>

        <main>
          <section class="club-panel min-h-[600px] p-6 md:p-8">
            <div class="mb-8 flex flex-col gap-5 md:flex-row md:items-center md:justify-between">
              <div>
                <p class="text-sm text-slate-400">All Members</p>
                <h2 class="mt-1 font-display text-3xl font-bold text-white">所有成员</h2>
                <p class="mt-2 text-sm text-slate-400">{{ filteredMembers().length }} 位成员</p>
              </div>

              <div class="relative w-full md:max-w-[280px]">
                <Search class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
                <input
                  v-model="searchQuery"
                  type="text"
                  placeholder="搜索成员姓名..."
                  class="club-input w-full py-4 pl-12 pr-4"
                />
              </div>
            </div>

            <div v-if="loading" class="flex justify-center py-20">
              <Loader2 class="h-8 w-8 animate-spin text-[#ecd7ad]" />
            </div>

            <div v-else class="overflow-x-auto">
              <table class="w-full min-w-[720px]">
                <thead>
                  <tr class="border-b border-white/8 text-left">
                    <th class="pb-4 pl-4 text-sm font-medium text-slate-400">成员信息</th>
                    <th class="pb-4 text-sm font-medium text-slate-400">职位角色</th>
                    <th class="pb-4 text-sm font-medium text-slate-400">加入时间</th>
                    <th class="pb-4 pr-4 text-right text-sm font-medium text-slate-400">操作</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-white/6">
                  <tr v-for="m in filteredMembers()" :key="m.id">
                    <td class="py-6 pl-4">
                      <div class="flex items-center gap-3">
                        <div class="h-11 w-11 overflow-hidden rounded-2xl border border-white/8 bg-white/5">
                          <img
                            :src="m.profiles?.avatar_url || `https://ui-avatars.com/api/?name=${m.profiles?.full_name}&background=111515&color=F7F2EA`"
                            :alt="m.profiles?.full_name || '成员头像'"
                            class="h-full w-full object-cover"
                          />
                        </div>
                        <div>
                          <div class="font-semibold text-white">{{ m.profiles?.full_name }}</div>
                          <div class="mt-1 text-xs text-slate-500">@{{ m.profiles?.username }}</div>
                        </div>
                      </div>
                    </td>
                    <td class="py-6">
                      <span
                        :class="[
                          'rounded-full border px-3 py-1 text-xs',
                          m.role === 'admin'
                            ? 'border-[#d6bf8f]/20 bg-[#d6bf8f]/10 text-[#ecd7ad]'
                            : m.role === 'leader'
                              ? 'border-[#6d8d7d]/20 bg-[#6d8d7d]/10 text-[#d9e7de]'
                              : 'border-white/8 bg-white/5 text-slate-300'
                        ]"
                      >
                        {{ m.role === 'admin' ? '管理员' : m.role === 'leader' ? '负责人' : '普通成员' }}
                      </span>
                    </td>
                    <td class="py-6 text-sm text-slate-400">
                      {{ new Date(m.joined_at).toLocaleDateString() }}
                    </td>
                    <td class="py-6 pr-4 text-right">
                      <div class="flex items-center justify-end gap-2">
                        <button
                          v-if="m.user_id !== authStore.user?.id"
                          type="button"
                          @click="handleRemoveMember(m.user_id)"
                          class="rounded-xl border border-rose-400/16 bg-rose-400/10 p-2 text-rose-100 transition-colors hover:bg-rose-400/16"
                        >
                          <Trash2 class="h-4 w-4" />
                        </button>
                        <button type="button" class="rounded-xl border border-white/8 bg-white/5 p-2 text-slate-300">
                          <MoreVertical class="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>

              <div v-if="filteredMembers().length === 0" class="flex flex-col items-center justify-center py-20 text-center">
                <User class="h-12 w-12 text-slate-500" />
                <p class="mt-4 text-base font-medium text-slate-300">未找到匹配的成员</p>
              </div>
            </div>
          </section>
        </main>
      </div>
    </div>
  </div>
</template>
