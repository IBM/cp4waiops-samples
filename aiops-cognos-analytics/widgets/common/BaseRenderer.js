/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024
 * 
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
import ProxyManager from './getProxy';
const getProxy = ProxyManager.getProxy;

class Renderer {
  constructor(options) {
    this.api = options.dashboardAPI;
    this.proxyHost = '';
  }

  initialize() {
    return getProxy(this.api.getDashboardInfo())
      .then(proxyHost => {
        this.proxyHost = proxyHost;
      });
  }
}

export default Renderer;
