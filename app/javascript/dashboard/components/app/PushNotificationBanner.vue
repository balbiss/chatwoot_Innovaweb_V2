<script>
import Banner from 'dashboard/components/ui/Banner.vue';
import { useAlert } from 'dashboard/composables';
import { requestPushPermissions } from 'dashboard/helper/pushHelper.js';

export default {
  components: { Banner },
  data() {
    return {
      dismissed: false,
      permissionState: this.getPermissionState(),
    };
  },
  computed: {
    hasPushAPISupport() {
      return (
        'Notification' in window &&
        'serviceWorker' in navigator &&
        'PushManager' in window
      );
    },
    isBlocked() {
      return this.permissionState === 'denied';
    },
    shouldShowBanner() {
      return (
        this.hasPushAPISupport &&
        this.permissionState !== 'granted' &&
        !this.dismissed
      );
    },
    bannerMessage() {
      return this.isBlocked
        ? this.$t('APP_GLOBAL.PUSH_NOTIFICATIONS_BLOCKED')
        : this.$t('APP_GLOBAL.ENABLE_PUSH_NOTIFICATIONS');
    },
  },
  mounted() {
    if (this.permissionState === 'granted') {
      // Ja concedeu a permissao do navegador antes (inclusive antes deste
      // banner existir) -- garante silenciosamente que as etiquetas de
      // notificacao da conta tambem estao corretas, sem precisar reexibir
      // nada pro agente.
      this.ensureAssignmentPushFlagsEnabled().catch(() => {});
    }
  },
  methods: {
    getPermissionState() {
      return 'Notification' in window ? Notification.permission : 'unsupported';
    },
    async ensureAssignmentPushFlagsEnabled() {
      await this.$store.dispatch('userNotificationSettings/get');
      const currentFlags =
        this.$store.getters['userNotificationSettings/getSelectedPushFlags'] ||
        [];
      const requiredFlags = [
        'push_conversation_assignment',
        'push_assigned_conversation_new_message',
      ];
      const missingFlags = requiredFlags.filter(
        flag => !currentFlags.includes(flag)
      );
      if (!missingFlags.length) {
        return;
      }
      await this.$store.dispatch('userNotificationSettings/update', {
        selectedEmailFlags:
          this.$store.getters[
            'userNotificationSettings/getSelectedEmailFlags'
          ] || [],
        selectedPushFlags: [...currentFlags, ...missingFlags],
      });
    },
    enableNotifications() {
      requestPushPermissions({
        onSuccess: async () => {
          this.permissionState = 'granted';
          try {
            await this.ensureAssignmentPushFlagsEnabled();
          } catch (error) {
            // A inscricao do dispositivo ja funcionou; se essa parte falhar,
            // o agente ainda pode ajustar em Perfil > Notificacoes.
          }
          useAlert(this.$t('APP_GLOBAL.PUSH_NOTIFICATIONS_ENABLED'));
        },
      });
    },
    dismissBanner() {
      this.dismissed = true;
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <Banner
    v-if="shouldShowBanner"
    color-scheme="primary"
    :banner-message="bannerMessage"
    :has-action-button="!isBlocked"
    action-button-icon="i-lucide-bell"
    :action-button-label="$t('APP_GLOBAL.ENABLE_PUSH_NOTIFICATIONS_BUTTON')"
    has-close-button
    @primary-action="enableNotifications"
    @close="dismissBanner"
  />
</template>
