/* global axios */

import ApiClient from './ApiClient';

class AsaasAPI extends ApiClient {
  constructor() {
    super('asaas', { accountScoped: true });
  }

  getSettings() {
    return axios.get(this.url);
  }

  updateSettings(data) {
    return axios.patch(this.url, data);
  }

  createCharge(data) {
    return axios.post(`${this.url}/create_charge`, data);
  }
}

export default new AsaasAPI();
