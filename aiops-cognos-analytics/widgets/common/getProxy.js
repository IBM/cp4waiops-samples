/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024
 * 
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
import { errorCheck } from './apiErrorCheck';

let instance;
const globalState = {};

const getCookie = (name) => {
  const cookies = new Map(document.cookie?.split(';').map(c => c.split('=').map(p => p.trim())));
  return cookies.get(name);
};

const getNamespace = () => {
  const account = window.__glassAppController?.glassContext?.profile?.account;
  if (account) {
    const id = account.id;
    const namespace = atob(id.substring(1).replaceAll('_', '=')).split(':')[0];
    console.debug('[getNamespace]', namespace);
    return namespace;
  }
  return 'cognos';
};

const getProxyForDashboard = async (id) => {
  let url = window.location;

  // keep for support
  const debug = sessionStorage.getItem('aiops_proxy');
  if (debug) return debug;

  // fetch the ns to get the custom proxy
  if (id) {
    const NAMESPACES_API_PATH = '/api/v1/configuration/namespaces/';
    try {
      const res = await errorCheck(fetch(NAMESPACES_API_PATH + id,
        {
          method: 'GET',
          headers: {
            'Accept': 'application/json',
            'IBM-BA-Authorization': `CAM ${getCookie('cam_passport')}`,
            'X-XSRF-Token': getCookie('XSRF-TOKEN')
          },
          credentials: 'include'
        }));
      const namespace = await res.json();
      if (namespace.customProperties.aiops_proxy) {
        url = new URL(namespace.customProperties.aiops_proxy);
      }
    } catch (e) {
      console.error('[getProxyForDashboard]', e);
    }
  }
  return url.protocol + '//' + url.host;
};

class ProxyManager {
  constructor() {
    if (instance) {
      return;
    }

    instance = this;
  }

  async getProxy() {
    const namespace = getNamespace();

    const cached = globalState[namespace];
    if (cached) return cached;

    globalState[namespace] = await getProxyForDashboard(namespace);
    return globalState[namespace];
  }
}

const ProxyManagerInstance = Object.freeze(new ProxyManager());

export default ProxyManagerInstance;
