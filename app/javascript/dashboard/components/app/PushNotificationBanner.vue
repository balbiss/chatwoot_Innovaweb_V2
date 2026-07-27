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
  methods: {
    getPermissionState() {
      return 'Notification' in window ? Notification.permission : 'unsupported';
    },
    enableNotifications() {
      requestPushPermissions({
        onSuccess: () => {
          this.permissionState = 'granted';
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
