<template>
  <div class="mx-6 max-w-4xl flex flex-col gap-6 pb-10">
    <!-- Enable/Disable -->
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 p-6">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">Assistente de IA</h3>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Ative para que a IA responda automaticamente no WhatsApp</p>
        </div>
        <input type="checkbox" v-model="form.ai_enabled" class="toggle-checkbox" @change="saveSettings" />
      </div>
    </div>

    <!-- Identidade -->
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 p-6 flex flex-col gap-4">
      <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">Identidade da IA</h3>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Nome da assistente</label>
        <input v-model="form.ai_name" type="text" placeholder="Ex: Beatriz, Luna, Max..." class="cw-input" @blur="saveSettings" />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Temperatura (criatividade)</label>
        <div class="flex items-center gap-3">
          <input v-model="form.ai_temperature" type="range" min="0.1" max="1.0" step="0.1" class="flex-1" @change="saveSettings" />
          <span class="text-sm font-mono w-8 text-center text-slate-600 dark:text-slate-300">{{ form.ai_temperature }}</span>
        </div>
        <p class="text-xs text-slate-400">0.3 = mais preciso e direto · 0.9 = mais criativo e variado</p>
      </div>
    </div>

    <!-- Wizard de Prompt -->
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 p-6 flex flex-col gap-4">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">Prompt da IA</h3>
          <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Descreva como a IA deve se comportar ou use o assistente abaixo</p>
        </div>
        <button class="text-sm text-woot-500 font-medium hover:underline" @click="showWizard = !showWizard">
          {{ showWizard ? 'Fechar assistente' : '✨ Gerar com IA' }}
        </button>
      </div>

      <!-- Wizard -->
      <div v-if="showWizard" class="border border-woot-200 dark:border-woot-700 rounded-lg p-4 flex flex-col gap-3 bg-woot-25 dark:bg-woot-900/20">
        <p class="text-sm font-semibold text-woot-700 dark:text-woot-300">✨ Assistente de criação de prompt</p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Nome do negócio *</label>
            <input v-model="wizard.business_name" type="text" placeholder="Studio Bella" class="cw-input text-sm" />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Segmento / Nicho *</label>
            <input v-model="wizard.segment" type="text" placeholder="Salão de beleza, Clínica, Restaurante..." class="cw-input text-sm" />
          </div>
          <div class="flex flex-col gap-1 md:col-span-2">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Produtos / Serviços oferecidos *</label>
            <input v-model="wizard.services" type="text" placeholder="Corte, escova, coloração, manicure..." class="cw-input text-sm" />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Tom de voz</label>
            <select v-model="wizard.tone" class="cw-input text-sm">
              <option value="Alegre e descontraído">Alegre e descontraído</option>
              <option value="Profissional e formal">Profissional e formal</option>
              <option value="Acolhedor e empático">Acolhedor e empático</option>
              <option value="Direto e objetivo">Direto e objetivo</option>
            </select>
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Nome da assistente</label>
            <input v-model="wizard.ai_name" type="text" placeholder="Luna" class="cw-input text-sm" />
          </div>
          <div class="flex flex-col gap-1 md:col-span-2">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Horário de funcionamento</label>
            <input v-model="wizard.working_hours" type="text" placeholder="Seg-Sex 9h-18h, Sáb 9h-14h" class="cw-input text-sm" />
          </div>
          <div class="flex flex-col gap-1 md:col-span-2">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Quando transferir para atendente humano</label>
            <input v-model="wizard.transfer_conditions" type="text" placeholder="Reclamações, pedidos de desconto, clientes com dificuldades..." class="cw-input text-sm" />
          </div>
          <div class="flex flex-col gap-1 md:col-span-2">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">O que a IA NUNCA deve fazer</label>
            <input v-model="wizard.never_do" type="text" placeholder="Dar desconto, falar mal de concorrentes, confirmar preços sem consultar..." class="cw-input text-sm" />
          </div>
          <div class="flex flex-col gap-1 md:col-span-2">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Diferenciais do negócio (opcional)</label>
            <input v-model="wizard.differentials" type="text" placeholder="Atendemos com hora marcada, produtos importados..." class="cw-input text-sm" />
          </div>
          <div class="flex flex-col gap-1 md:col-span-2">
            <label class="text-xs font-medium text-slate-600 dark:text-slate-400">Perguntas frequentes (opcional)</label>
            <textarea v-model="wizard.faq" rows="2" placeholder="'Aceitam cartão?' → Sim, todas as bandeiras&#10;'Tem estacionamento?' → Sim, gratuito" class="cw-input text-sm" />
          </div>
        </div>
        <button
          class="mt-1 w-full py-2 rounded-lg bg-woot-500 text-white text-sm font-semibold hover:bg-woot-600 transition disabled:opacity-50"
          :disabled="isGenerating"
          @click="generatePrompt"
        >
          {{ isGenerating ? 'Gerando...' : '✨ Gerar Prompt' }}
        </button>
      </div>

      <textarea
        v-model="form.ai_prompt"
        rows="10"
        placeholder="Descreva aqui como a IA deve se comportar, o que pode e não pode fazer, como deve abordar os clientes..."
        class="cw-input font-mono text-xs"
        @blur="saveSettings"
      />
    </div>

    <!-- Saudação -->
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 p-6 flex flex-col gap-4">
      <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">Saudação</h3>
      <label class="flex items-center gap-2 text-sm cursor-pointer">
        <input type="checkbox" v-model="form.ai_greeting_use_name" @change="saveSettings" />
        <span class="text-slate-700 dark:text-slate-300">Chamar pelo nome do WhatsApp (quando disponível)</span>
      </label>
      <label class="flex items-center gap-2 text-sm cursor-pointer">
        <input type="checkbox" v-model="form.ai_greeting_use_time" @change="saveSettings" />
        <span class="text-slate-700 dark:text-slate-300">Usar "Bom dia / Boa tarde / Boa noite" conforme horário</span>
      </label>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Mensagem de primeiro contato</label>
        <textarea v-model="form.ai_first_message" rows="2" placeholder="Olá {nome}! Seja bem-vindo(a)! Em que posso ajudar?" class="cw-input text-sm" @blur="saveSettings" />
        <p class="text-xs text-slate-400">Use {nome} para inserir o nome do cliente</p>
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Mensagem para cliente que já conversou antes</label>
        <textarea v-model="form.ai_return_message" rows="2" placeholder="Oi {nome}, que saudade! Como posso te ajudar hoje?" class="cw-input text-sm" @blur="saveSettings" />
      </div>
    </div>

    <!-- Follow-up -->
    <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 p-6 flex flex-col gap-4">
      <div class="flex items-center justify-between">
        <h3 class="text-base font-semibold text-slate-800 dark:text-slate-100">Follow-up Automático</h3>
        <input type="checkbox" v-model="form.ai_followup_enabled" @change="saveSettings" />
      </div>
      <p class="text-sm text-slate-500 dark:text-slate-400 -mt-2">Quando ativado, a IA enviará mensagens automáticas para clientes que pararam de responder</p>

      <div v-if="form.ai_followup_enabled" class="flex flex-col gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Aguardar quanto tempo antes do 1º follow-up</label>
          <div class="flex items-center gap-2">
            <input v-model.number="form.ai_followup_wait_minutes" type="number" min="30" max="1440" step="30" class="cw-input w-28" @blur="saveSettings" />
            <span class="text-sm text-slate-500">minutos</span>
          </div>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Máximo de tentativas</label>
          <input v-model.number="form.ai_followup_max_attempts" type="number" min="1" max="10" class="cw-input w-28" @blur="saveSettings" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Mensagem de encerramento (após esgotar tentativas)</label>
          <textarea v-model="form.ai_followup_closing_message" rows="2" placeholder="Oi {nome}! Tentei algumas vezes mas não consegui retorno. Quando quiser retomar é só chamar! 😊" class="cw-input text-sm" @blur="saveSettings" />
        </div>
      </div>
    </div>

    <!-- Save -->
    <div class="flex justify-end">
      <button
        class="px-6 py-2 rounded-lg bg-woot-500 text-white text-sm font-semibold hover:bg-woot-600 transition disabled:opacity-50"
        :disabled="isSaving"
        @click="saveSettings"
      >
        {{ isSaving ? 'Salvando...' : 'Salvar configurações de IA' }}
      </button>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import axios from 'axios';

export default {
  name: 'AiSettings',
  props: {
    inbox: { type: Object, required: true },
  },
  data() {
    return {
      isSaving: false,
      isGenerating: false,
      showWizard: false,
      form: {
        ai_enabled: false,
        ai_name: '',
        ai_temperature: 0.7,
        ai_prompt: '',
        ai_greeting_use_name: true,
        ai_greeting_use_time: true,
        ai_first_message: '',
        ai_return_message: '',
        ai_followup_enabled: false,
        ai_followup_wait_minutes: 120,
        ai_followup_max_attempts: 3,
        ai_followup_closing_message: '',
      },
      wizard: {
        business_name: '',
        segment: '',
        services: '',
        tone: 'Alegre e descontraído',
        ai_name: '',
        working_hours: '',
        transfer_conditions: '',
        never_do: '',
        differentials: '',
        faq: '',
      },
    };
  },
  computed: {
    ...mapGetters({ accountId: 'getCurrentAccountId' }),
  },
  watch: {
    inbox: {
      immediate: true,
      handler(val) {
        if (!val) return;
        this.form.ai_enabled = val.ai_enabled || false;
        this.form.ai_name = val.ai_name || '';
        this.form.ai_temperature = val.ai_temperature || 0.7;
        this.form.ai_prompt = val.ai_prompt || '';
        this.form.ai_greeting_use_name = val.ai_greeting_use_name !== false;
        this.form.ai_greeting_use_time = val.ai_greeting_use_time !== false;
        this.form.ai_first_message = val.ai_first_message || '';
        this.form.ai_return_message = val.ai_return_message || '';
        this.form.ai_followup_enabled = val.ai_followup_enabled || false;
        this.form.ai_followup_wait_minutes = val.ai_followup_wait_minutes || 120;
        this.form.ai_followup_max_attempts = val.ai_followup_max_attempts || 3;
        this.form.ai_followup_closing_message = val.ai_followup_closing_message || '';
      },
    },
  },
  methods: {
    async saveSettings() {
      this.isSaving = true;
      try {
        await this.$store.dispatch('inboxes/updateInbox', {
          id: this.inbox.id,
          formData: false,
          channel: {},
          ...this.form,
        });
        this.$store.dispatch('notifications/show', {
          type: 'success',
          message: 'Configurações de IA salvas!',
        });
      } catch (e) {
        this.$store.dispatch('notifications/show', {
          type: 'error',
          message: 'Erro ao salvar configurações de IA',
        });
      } finally {
        this.isSaving = false;
      }
    },
    async generatePrompt() {
      if (!this.wizard.business_name || !this.wizard.segment || !this.wizard.services) {
        alert('Preencha pelo menos Nome do negócio, Segmento e Serviços/Produtos.');
        return;
      }
      this.isGenerating = true;
      try {
        const { data } = await axios.post(
          `/api/v1/accounts/${this.accountId}/ai_generate_prompt`,
          { wizard: this.wizard },
          { headers: { api_access_token: this.$store.getters['auth/getCurrentUser']?.access_token } }
        );
        this.form.ai_prompt = data.prompt;
        if (this.wizard.ai_name) this.form.ai_name = this.wizard.ai_name;
        this.showWizard = false;
      } catch (e) {
        alert('Erro ao gerar prompt: ' + (e?.response?.data?.error || e.message));
      } finally {
        this.isGenerating = false;
      }
    },
  },
};
</script>
