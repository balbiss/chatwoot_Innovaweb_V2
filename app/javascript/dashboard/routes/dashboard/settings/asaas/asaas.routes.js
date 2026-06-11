import { frontendURL } from '../../../../helper/URLHelper';
import {
  ROLES,
  CONVERSATION_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

const AsaasSettings = () => import('./AsaasSettings.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/asaas'),
      name: 'asaas_settings',
      meta: {
        permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
      },
      component: AsaasSettings,
    },
  ],
};
