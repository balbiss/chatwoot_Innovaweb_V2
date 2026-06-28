<template>
  <div v-if="showBanner" class="flex items-center gap-2 px-4 py-2 text-xs" :class="bannerClass">
    <span class="text-base">{{ aiActive ? '🤖' : '⏸️' }}</span>
    <span class="flex-1">
      <span v-if="aiActive" class="font-semibold">IA ativa</span>
      <span v-else class="font-semibold">IA pausada</span>
      <span v-if="!aiActive && remainingMinutes" class="ml-1 opacity-75">· retoma em {{ remainingMinutes }} min</span>
      <span v-else-if="!aiActive" class="ml-1 opacity-75">· pausada por agente ou manual</span>
    </span>
    <button
      v-if="!aiActive"
      class="text-xs font-semibold underline opacity-80 hover:opacity-100"
      @click="resumeAi"
    >
      Retomar IA
    </button>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import axios from 'axios';

const props = defineProps({
  conversation: { type: Object, required: true },
});

const store = useStore();
const aiStatus = ref(null);
const isLoading = ref(false);

const accountId = computed(() => store.getters['getCurrentAccountId']);
const inbox = computed(() => store.getters['inboxes/getInbox'](props.conversation.inbox_id));

const isBaileysInbox = computed(() => inbox.value?.channel_type === 'Channel::Whatsapp' && inbox.value?.medium === 'baileys');
const inboxHasAi = computed(() => inbox.value?.ai_prompt?.length > 0);

const showBanner = computed(() => isBaileysInbox.value && inboxHasAi.value);
const aiActive = computed(() => showBanner.value && aiStatus.value !== null && !aiStatus.value?.paused);
const remainingMinutes = computed(() => {
  const s = aiStatus.value?.remaining_seconds;
  return s ? Math.ceil(s / 60) : null;
});

const bannerClass = computed(() =>
  aiActive.value
    ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300 border-b border-emerald-100 dark:border-emerald-800'
    : 'bg-amber-50 dark:bg-amber-900/20 text-amber-700 dark:text-amber-300 border-b border-amber-100 dark:border-amber-800'
);

const apiHeaders = computed(() => ({
  api_access_token: store.getters['auth/getCurrentUser']?.access_token,
}));

async function fetchStatus() {
  if (!showBanner.value) return;
  try {
    const { data } = await axios.get(
      `/api/v1/accounts/${accountId.value}/conversations/${props.conversation.id}/ai_status`,
      { headers: apiHeaders.value }
    );
    aiStatus.value = data;
  } catch {
    aiStatus.value = null;
  }
}

async function resumeAi() {
  isLoading.value = true;
  try {
    await axios.post(
      `/api/v1/accounts/${accountId.value}/conversations/${props.conversation.id}/resume_ai`,
      {},
      { headers: apiHeaders.value }
    );
    aiStatus.value = { paused: false, remaining_seconds: null };
  } finally {
    isLoading.value = false;
  }
}

onMounted(() => { fetchStatus(); });
watch(() => props.conversation.id, fetchStatus);

let pollInterval;
onMounted(() => { pollInterval = setInterval(fetchStatus, 30000); });
import { onUnmounted } from 'vue';
onUnmounted(() => clearInterval(pollInterval));
</script>
