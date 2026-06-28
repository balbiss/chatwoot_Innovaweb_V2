import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';

const CatalogPage = () => import('./CatalogPage.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/catalog'),
      name: 'catalog_settings',
      meta: { permissions: ROLES },
      component: CatalogPage,
    },
  ],
};
