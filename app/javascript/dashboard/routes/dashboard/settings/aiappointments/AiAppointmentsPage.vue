<template>
  <div class="flex flex-col h-full">
    <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 dark:border-slate-700">
      <div>
        <h1 class="text-xl font-semibold text-slate-800 dark:text-slate-100">Agendamentos</h1>
        <p class="text-sm text-slate-500 dark:text-slate-400">Agendamentos criados pela IA e pela equipe</p>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex items-center gap-3 px-6 py-3 border-b border-slate-50 dark:border-slate-800">
      <select v-model="filterStatus" class="cw-input text-sm w-44" @change="loadAppointments">
        <option value="">Todos os status</option>
        <option value="scheduled">Agendado</option>
        <option value="confirmed">Confirmado</option>
        <option value="completed">Concluído</option>
        <option value="cancelled">Cancelado</option>
        <option value="no_show">Não compareceu</option>
      </select>
    </div>

    <!-- List -->
    <div class="flex-1 overflow-y-auto px-6 py-4">
      <div v-if="isLoading" class="flex justify-center py-12">
        <span class="text-slate-400 text-sm">Carregando...</span>
      </div>
      <div v-else-if="appointments.length === 0" class="flex flex-col items-center py-16 gap-3">
        <span class="text-4xl">📅</span>
        <p class="text-slate-500 text-sm">Nenhum agendamento encontrado</p>
      </div>
      <div v-else class="flex flex-col gap-3">
        <div
          v-for="a in appointments"
          :key="a.id"
          class="bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 p-4 flex items-center gap-4"
        >
          <div class="w-12 h-12 rounded-xl flex flex-col items-center justify-center text-center" :class="statusColor(a.status)">
            <span class="text-lg font-bold leading-none">{{ formatDay(a.appointment_date) }}</span>
            <span class="text-xs leading-none mt-0.5">{{ formatMonth(a.appointment_date) }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <p class="font-semibold text-slate-800 dark:text-slate-100 text-sm truncate">{{ a.contact?.name || a.contact?.phone_number }}</p>
            <p class="text-xs text-slate-500 dark:text-slate-400">
              {{ a.start_time }}{{ a.end_time ? ' – ' + a.end_time : '' }}
              <span v-if="a.catalog_item"> · {{ a.catalog_item.name }}</span>
              <span v-if="a.assignee"> · {{ a.assignee.name }}</span>
            </p>
            <p v-if="a.notes" class="text-xs text-slate-400 dark:text-slate-500 truncate">{{ a.notes }}</p>
          </div>
          <select
            v-model="a.status"
            class="text-xs border border-slate-200 dark:border-slate-600 rounded-lg px-2 py-1 bg-transparent"
            @change="updateStatus(a)"
          >
            <option value="scheduled">Agendado</option>
            <option value="confirmed">Confirmado</option>
            <option value="completed">Concluído</option>
            <option value="cancelled">Cancelado</option>
            <option value="no_show">Não compareceu</option>
          </select>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import axios from 'axios';

const STATUS_COLORS = {
  scheduled: 'bg-blue-100 text-blue-700',
  confirmed: 'bg-green-100 text-green-700',
  completed: 'bg-slate-100 text-slate-500',
  cancelled: 'bg-red-100 text-red-500',
  no_show: 'bg-orange-100 text-orange-600',
};

const MONTHS = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

export default {
  name: 'AiAppointmentsPage',
  data() {
    return { appointments: [], isLoading: false, filterStatus: '' };
  },
  computed: {
    ...mapGetters({ accountId: 'getCurrentAccountId' }),
    apiHeaders() {
      return { api_access_token: this.$store.getters['auth/getCurrentUser']?.access_token };
    },
  },
  mounted() { this.loadAppointments(); },
  methods: {
    async loadAppointments() {
      this.isLoading = true;
      try {
        const params = this.filterStatus ? { status: this.filterStatus } : {};
        const { data } = await axios.get(`/api/v1/accounts/${this.accountId}/ai_appointments`, { params, headers: this.apiHeaders });
        this.appointments = data;
      } finally {
        this.isLoading = false;
      }
    },
    async updateStatus(a) {
      await axios.patch(`/api/v1/accounts/${this.accountId}/ai_appointments/${a.id}`, { ai_appointment: { status: a.status } }, { headers: this.apiHeaders });
    },
    statusColor(s) { return STATUS_COLORS[s] || 'bg-slate-100 text-slate-500'; },
    formatDay(d) { return d ? new Date(d + 'T00:00:00').getDate() : '--'; },
    formatMonth(d) { return d ? MONTHS[new Date(d + 'T00:00:00').getMonth()] : '---'; },
  },
};
</script>
