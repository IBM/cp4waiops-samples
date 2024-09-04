/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024
 * 
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
import { errorCheck } from './apiErrorCheck';

const tenantId = 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255';

const ALERT_SUMMARY = `query($tenantId: ID! $filter: String $groupBy: [String]) {
  tenant(id: $tenantId) {
    alertSummary(filter: $filter groupBy: $groupBy)
  }
}`;

function getQuery() {
  return {
    query: `${ALERT_SUMMARY}`
  };
}

class AlertSummaryAPI {
  groupBy = ['severity'];

  constructor({groupBy, proxyHost = ''}) {
    this.groupBy = groupBy;
    this.proxyHost = proxyHost;
  }

  async getData({filter = ''}) {
    const GQL_API_PATH = this.proxyHost + '/api/p/hdm_ea_uiapi';
    const res = await errorCheck(fetch(GQL_API_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Origin': window.location.origin },
      mode: 'cors',
      credentials: 'include',
      body: JSON.stringify({
        ...getQuery(),
        variables: {
          tenantId,
          filter,
          groupBy: this.groupBy
        }
      })
    }));

    return await res.json();
  }
}

export default AlertSummaryAPI;
