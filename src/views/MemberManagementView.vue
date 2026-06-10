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
  <div class="min-h-screen bg-wanderlust p-4 lg:p-8">
    <div class="max-w-5xl mx-auto">
      <header class="flex items-center justify-between mb-8">
        <button @click="router.back()" class="flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:shadow-md transition-all font-bold text-slate-600">
          <ArrowLeft class="w-5 h-5" />
          返回
        </button>
        <h1 class="text-xl font-bold text-slate-900">社员信息管理</h1>
        <div class="w-20"></div>
      </header>

      <div v-if="myClubs.length === 0 && !loading" class="bg-white p-12 rounded-[3rem] shadow-xl text-center">
        <Users class="w-16 h-16 text-slate-200 mx-auto mb-4" />
        <h2 class="text-2xl font-bold text-slate-800 mb-2">您还没有管理的社团</h2>
        <button @click="router.push('/create-club')" class="bg-primary text-white px-8 py-3 rounded-2xl font-bold shadow-lg shadow-primary/20">创建社团</button>
      </div>

      <div v-else class="grid grid-cols-1 lg:grid-cols-4 gap-8">
        <!-- 左侧社团列表 -->
        <aside class="lg:col-span-1 space-y-4">
          <div class="bg-white p-6 rounded-[2.5rem] shadow-xl">
            <h3 class="font-bold text-xs text-slate-400 uppercase tracking-widest mb-4 ml-2">管理的社团</h3>
            <div class="space-y-2">
              <button v-for="club in myClubs" :key="club.id"
                      @click="selectedClubId = club.id; fetchMembers()"
                      :class="['w-full flex items-center gap-3 p-4 rounded-2xl transition-all font-bold text-left', 
                               selectedClubId === club.id ? 'bg-primary text-white shadow-lg shadow-primary/20' : 'hover:bg-slate-50 text-slate-600']">
                <ShieldCheck class="w-5 h-5" />
                <span class="truncate">{{ club.name }}</span>
              </button>
            </div>
          </div>
        </aside>

        <!-- 右侧成员列表 -->
        <main class="lg:col-span-3 space-y-6">
          <section class="bg-white p-8 rounded-[3rem] shadow-xl min-h-[600px]">
            <div class="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-8">
              <div>
                <h2 class="text-2xl font-bold text-slate-900">所有成员</h2>
                <p class="text-sm text-slate-400 font-bold uppercase tracking-wider mt-1">{{ filteredMembers().length }} 位成员</p>
              </div>

              <div class="flex items-center gap-3 bg-slate-50 p-2 rounded-2xl border border-slate-100 min-w-[250px]">
                <Search class="w-5 h-5 text-slate-300 ml-2" />
                <input v-model="searchQuery" type="text" placeholder="搜索成员姓名..." class="bg-transparent border-none outline-none flex-1 text-sm font-bold" />
              </div>
            </div>

            <div v-if="loading" class="flex justify-center py-20">
              <Loader2 class="w-8 h-8 animate-spin text-primary" />
            </div>

            <div v-else class="overflow-x-auto">
              <table class="w-full">
                <thead>
                  <tr class="text-left border-b border-slate-50">
                    <th class="pb-4 pl-4 text-xs font-bold text-slate-400 uppercase tracking-widest">成员信息</th>
                    <th class="pb-4 text-xs font-bold text-slate-400 uppercase tracking-widest">职位角色</th>
                    <th class="pb-4 text-xs font-bold text-slate-400 uppercase tracking-widest">加入时间</th>
                    <th class="pb-4 pr-4 text-right text-xs font-bold text-slate-400 uppercase tracking-widest">操作</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-50">
                  <tr v-for="m in filteredMembers()" :key="m.id" class="group">
                    <td class="py-6 pl-4">
                      <div class="flex items-center gap-3">
                        <div class="w-10 h-10 rounded-xl bg-slate-100 overflow-hidden shadow-sm">
                          <img :src="m.profiles?.avatar_url || `https://ui-avatars.com/api/?name=${m.profiles?.full_name}&background=random`" class="w-full h-full object-cover" />
                        </div>
                        <div>
                          <div class="font-bold text-slate-800">{{ m.profiles?.full_name }}</div>
                          <div class="text-xs text-slate-400 font-medium">@{{ m.profiles?.username }}</div>
                        </div>
                      </div>
                    </td>
                    <td class="py-6">
                      <span :class="['px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-widest', 
                                     m.role === 'admin'
                                       ? 'bg-amber-50 text-amber-600'
                                       : m.role === 'leader'
                                         ? 'bg-blue-50 text-blue-500'
                                         : 'bg-slate-50 text-slate-500']">
                        {{ m.role === 'admin' ? '管理员' : m.role === 'leader' ? '负责人' : '普通成员' }}
                      </span>
                    </td>
                    <td class="py-6 text-sm text-slate-500 font-medium">
                      {{ new Date(m.joined_at).toLocaleDateString() }}
                    </td>
                    <td class="py-6 pr-4 text-right">
                      <div class="flex items-center justify-end gap-2">
                        <button v-if="m.user_id !== authStore.user?.id" 
                                @click="handleRemoveMember(m.user_id)"
                                class="p-2 text-slate-300 hover:text-red-500 transition-colors">
                          <Trash2 class="w-5 h-5" />
                        </button>
                        <button class="p-2 text-slate-300 hover:text-primary transition-colors">
                          <MoreVertical class="w-5 h-5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
              
              <div v-if="filteredMembers().length === 0" class="flex flex-col items-center justify-center py-20 text-slate-300">
                <User class="w-12 h-12 mb-4" />
                <p class="font-bold">未找到匹配的成员</p>
              </div>
            </div>
          </section>
        </main>
      </div>
    </div>
  </div>
</template>
