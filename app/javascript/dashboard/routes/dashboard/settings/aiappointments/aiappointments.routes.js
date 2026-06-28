import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';

const AiAppointmentsPage = () => import('./AiAppointmentsPage.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai-appointments'),
      name: 'ai_appointments',
      meta: { permissions: ROLES },
      component: AiAppointmentsPage,
    },
  ],
};
