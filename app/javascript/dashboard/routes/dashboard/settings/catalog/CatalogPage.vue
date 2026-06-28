<template>
  <div class="flex flex-col h-full">
    <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100 dark:border-slate-700">
      <div>
        <h1 class="text-xl font-semibold text-slate-800 dark:text-slate-100">Catálogo</h1>
        <p class="text-sm text-slate-500 dark:text-slate-400">Produtos e serviços disponíveis para a IA apresentar</p>
      </div>
      <button class="px-4 py-2 bg-woot-500 text-white rounded-lg text-sm font-semibold hover:bg-woot-600" @click="openModal(null)">
        + Adicionar item
      </button>
    </div>

    <!-- Filters -->
    <div class="flex items-center gap-3 px-6 py-3 border-b border-slate-50 dark:border-slate-800">
      <input v-model="search" type="text" placeholder="Buscar..." class="cw-input text-sm w-64" />
      <select v-model="filterCategory" class="cw-input text-sm w-40">
        <option value="">Todas categorias</option>
        <option v-for="cat in categories" :key="cat" :value="cat">{{ cat }}</option>
      </select>
    </div>

    <!-- List -->
    <div class="flex-1 overflow-y-auto px-6 py-4">
      <div v-if="isLoading" class="flex justify-center py-12">
        <span class="text-slate-400 text-sm">Carregando...</span>
      </div>
      <div v-else-if="filteredItems.length === 0" class="flex flex-col items-center py-16 gap-3">
        <span class="text-4xl">📦</span>
        <p class="text-slate-500 text-sm">Nenhum item cadastrado ainda</p>
        <button class="text-sm text-woot-500 underline" @click="openModal(null)">Adicionar o primeiro item</button>
      </div>
      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div
          v-for="item in filteredItems"
          :key="item.id"
          class="bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 overflow-hidden flex flex-col"
        >
          <div class="bg-slate-100 dark:bg-slate-700 h-40 flex items-center justify-center relative overflow-hidden">
            <img v-if="item.photos && item.photos.length" :src="item.photos[0].url" class="w-full h-full object-cover" />
            <span v-else class="text-3xl text-slate-300">🖼️</span>
            <span v-if="!item.active" class="absolute top-2 right-2 bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">Inativo</span>
          </div>
          <div class="p-4 flex flex-col gap-1 flex-1">
            <div class="flex items-start justify-between gap-2">
              <h3 class="font-semibold text-slate-800 dark:text-slate-100 text-sm leading-tight">{{ item.name }}</h3>
              <span v-if="item.category" class="text-xs bg-slate-100 dark:bg-slate-700 text-slate-500 px-2 py-0.5 rounded-full whitespace-nowrap">{{ item.category }}</span>
            </div>
            <p v-if="item.description" class="text-xs text-slate-500 dark:text-slate-400 line-clamp-2">{{ item.description }}</p>
            <div class="flex items-center gap-3 mt-auto pt-2">
              <span v-if="item.price_formatted" class="text-sm font-semibold text-woot-600 dark:text-woot-400">{{ item.price_formatted }}</span>
              <span v-if="item.duration_minutes" class="text-xs text-slate-400">⏱ {{ item.duration_minutes }}min</span>
            </div>
          </div>
          <div class="flex border-t border-slate-100 dark:border-slate-700">
            <button class="flex-1 py-2 text-xs text-slate-500 hover:bg-slate-50 dark:hover:bg-slate-700" @click="openModal(item)">Editar</button>
            <button class="flex-1 py-2 text-xs text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20" @click="deleteItem(item)">Excluir</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" @click.self="closeModal">
      <div class="bg-white dark:bg-slate-800 rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto p-6 flex flex-col gap-4">
        <h2 class="text-lg font-semibold text-slate-800 dark:text-slate-100">{{ editingItem ? 'Editar item' : 'Novo item' }}</h2>

        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Nome *</label>
          <input v-model="modalForm.name" type="text" class="cw-input" />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Categoria</label>
            <input v-model="modalForm.category" type="text" placeholder="Corte, Consulta, Pizza..." class="cw-input" />
          </div>
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Preço (R$)</label>
            <input v-model="modalForm.price" type="number" step="0.01" min="0" class="cw-input" />
          </div>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Duração (minutos)</label>
          <input v-model="modalForm.duration_minutes" type="number" min="0" placeholder="Ex: 60" class="cw-input" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Descrição</label>
          <textarea v-model="modalForm.description" rows="3" class="cw-input" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Fotos</label>
          <input type="file" accept="image/*" multiple @change="onPhotosChange" class="text-sm text-slate-500" />
          <div v-if="existingPhotos.length" class="flex flex-wrap gap-2 mt-1">
            <div v-for="photo in existingPhotos" :key="photo.id" class="relative w-16 h-16">
              <img :src="photo.url" class="w-full h-full object-cover rounded-lg" />
              <button class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white rounded-full text-xs leading-5 text-center" @click="removeExistingPhoto(photo)">×</button>
            </div>
          </div>
        </div>
        <label class="flex items-center gap-2 text-sm cursor-pointer">
          <input type="checkbox" v-model="modalForm.active" />
          <span class="text-slate-700 dark:text-slate-300">Item ativo (visível para a IA)</span>
        </label>
        <div class="flex gap-3 pt-2">
          <button class="flex-1 py-2 rounded-lg border border-slate-200 dark:border-slate-600 text-sm text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700" @click="closeModal">Cancelar</button>
          <button class="flex-1 py-2 rounded-lg bg-woot-500 text-white text-sm font-semibold hover:bg-woot-600 disabled:opacity-50" :disabled="isSaving" @click="saveItem">
            {{ isSaving ? 'Salvando...' : 'Salvar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import axios from 'axios';

export default {
  name: 'CatalogPage',
  data() {
    return {
      items: [],
      isLoading: false,
      isSaving: false,
      showModal: false,
      editingItem: null,
      search: '',
      filterCategory: '',
      newPhotos: [],
      existingPhotos: [],
      modalForm: { name: '', category: '', price: '', duration_minutes: '', description: '', active: true },
    };
  },
  computed: {
    ...mapGetters({ accountId: 'getCurrentAccountId' }),
    categories() {
      return [...new Set(this.items.map(i => i.category).filter(Boolean))];
    },
    filteredItems() {
      return this.items.filter(i => {
        const matchSearch = !this.search || i.name.toLowerCase().includes(this.search.toLowerCase());
        const matchCat = !this.filterCategory || i.category === this.filterCategory;
        return matchSearch && matchCat;
      });
    },
    apiHeaders() {
      return { api_access_token: this.$store.getters['auth/getCurrentUser']?.access_token };
    },
  },
  mounted() {
    this.loadItems();
  },
  methods: {
    async loadItems() {
      this.isLoading = true;
      try {
        const { data } = await axios.get(`/api/v1/accounts/${this.accountId}/catalog_items`, { headers: this.apiHeaders });
        this.items = data;
      } finally {
        this.isLoading = false;
      }
    },
    openModal(item) {
      this.editingItem = item;
      this.newPhotos = [];
      if (item) {
        this.modalForm = { name: item.name, category: item.category || '', price: item.price || '', duration_minutes: item.duration_minutes || '', description: item.description || '', active: item.active };
        this.existingPhotos = [...(item.photos || [])];
      } else {
        this.modalForm = { name: '', category: '', price: '', duration_minutes: '', description: '', active: true };
        this.existingPhotos = [];
      }
      this.showModal = true;
    },
    closeModal() { this.showModal = false; this.editingItem = null; },
    onPhotosChange(e) { this.newPhotos = Array.from(e.target.files); },
    removeExistingPhoto(photo) { this.existingPhotos = this.existingPhotos.filter(p => p.id !== photo.id); },
    async saveItem() {
      if (!this.modalForm.name) { alert('Informe o nome do item'); return; }
      this.isSaving = true;
      try {
        const fd = new FormData();
        Object.entries(this.modalForm).forEach(([k, v]) => fd.append(`catalog_item[${k}]`, v));
        this.newPhotos.forEach(p => fd.append('photos[]', p));

        if (this.editingItem) {
          const { data } = await axios.patch(`/api/v1/accounts/${this.accountId}/catalog_items/${this.editingItem.id}`, fd, { headers: this.apiHeaders });
          const idx = this.items.findIndex(i => i.id === this.editingItem.id);
          if (idx !== -1) this.items.splice(idx, 1, data);
        } else {
          const { data } = await axios.post(`/api/v1/accounts/${this.accountId}/catalog_items`, fd, { headers: this.apiHeaders });
          this.items.unshift(data);
        }
        this.closeModal();
      } catch (e) {
        alert('Erro ao salvar: ' + (e?.response?.data?.errors?.join(', ') || e.message));
      } finally {
        this.isSaving = false;
      }
    },
    async deleteItem(item) {
      if (!confirm(`Excluir "${item.name}"?`)) return;
      await axios.delete(`/api/v1/accounts/${this.accountId}/catalog_items/${item.id}`, { headers: this.apiHeaders });
      this.items = this.items.filter(i => i.id !== item.id);
    },
  },
};
</script>
