<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { Loader2, Plus, X } from 'lucide-vue-next'

const props = defineProps<{
  modelValue: string
  bucket?: string
  folder?: string
}>()

const emit = defineEmits(['update:modelValue'])

const uploading = ref(false)
const fileInput = ref<HTMLInputElement | null>(null)

const handleFileChange = async (e: Event) => {
  const files = (e.target as HTMLInputElement).files
  if (!files || files.length === 0) return

  const file = files[0]
  const fileExt = file.name.split('.').pop()
  const fileName = `${Math.random().toString(36).substring(2)}.${fileExt}`
  const filePath = props.folder ? `${props.folder}/${fileName}` : fileName

  uploading.value = true
  try {
    const { error: uploadError } = await supabase.storage
      .from(props.bucket || 'avatars')
      .upload(filePath, file)

    if (uploadError) throw uploadError

    const { data: { publicUrl } } = supabase.storage
      .from(props.bucket || 'avatars')
      .getPublicUrl(filePath)

    emit('update:modelValue', publicUrl)
  } catch (error: any) {
    alert('图片上传失败: ' + error.message)
  } finally {
    uploading.value = false
  }
}

const clearImage = () => {
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="relative group w-32 h-32">
    <div 
      @click="fileInput?.click()"
      class="w-full h-full rounded-[2.5rem] border border-dashed border-white/15 bg-[rgba(9,12,20,0.86)] flex flex-col items-center justify-center text-slate-400 hover:border-[#e7d29c]/45 hover:text-[#f2ddae] transition-all cursor-pointer overflow-hidden shadow-[0_20px_35px_-14px_rgba(0,0,0,0.55)]"
    >
      <img v-if="modelValue" :src="modelValue" class="w-full h-full object-cover" />
      <div v-else-if="uploading" class="flex flex-col items-center">
        <Loader2 class="w-8 h-8 animate-spin text-primary mb-2" />
        <span class="text-[10px] font-bold uppercase tracking-widest text-primary">上传中...</span>
      </div>
      <div v-else class="flex flex-col items-center">
        <Plus class="w-8 h-8 mb-1" />
        <span class="text-[10px] font-bold uppercase tracking-widest">选择图片</span>
      </div>
      
      <div v-if="modelValue && !uploading" class="absolute inset-0 bg-black/45 opacity-0 group-hover:opacity-100 flex items-center justify-center text-white transition-opacity">
        <Plus class="w-6 h-6" />
      </div>
    </div>

    <button 
      v-if="modelValue && !uploading" 
      @click.stop="clearImage"
      class="absolute -top-2 -right-2 bg-[rgba(19,23,36,0.96)] text-rose-300 p-1.5 rounded-full shadow-lg hover:scale-110 transition-transform border border-white/10"
    >
      <X class="w-4 h-4" />
    </button>

    <input 
      ref="fileInput"
      type="file" 
      accept="image/*" 
      class="hidden" 
      @change="handleFileChange"
    />
  </div>
</template>
