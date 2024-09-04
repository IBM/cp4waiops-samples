/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024
 * 
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
import { errorCheck } from './apiErrorCheck';

const tenantId = 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255';
const FILTERS_QUERY = `filters(condition: $condition) {
  id
  name
  description
  type
  conditionSet {
    operator
    conditions
  }
}`;

const VIEWS_QUERY = `views(viewType: $viewType) {
  id
  name
  description
  type
}`;

function getQueries(options) {
  if (options.indexOf('filter') !== -1 && options.indexOf('view') !== -1) {
    return {
      query: `
        query($tenantId: ID! $condition: String $viewType: String) {
          tenant(id: $tenantId) {
            ${FILTERS_QUERY}
            ${VIEWS_QUERY}
          }
        }
      `
    };
  }
  if (options.indexOf('filter') !== -1 && options.indexOf('view') === -1) {
    return {
      query: `
        query($tenantId: ID! $condition: String) {
          tenant(id: $tenantId) {
            ${FILTERS_QUERY}
          }
        }
      `
    };
  }
  if (options.indexOf('filter') === -1 && options.indexOf('view') !== -1) {
    return {
      query: `
        query($tenantId: ID! $viewType: String) {
          tenant(id: $tenantId) {
            ${VIEWS_QUERY}
          }
        }
      `
    };
  }
}

class FilterViewAPI {
  // options can contain 'filter' and 'view' as options
  options = []
  // type can be either 'alert' or 'story
  type = null

  constructor({options, type, proxyHost = ''}) {
    this.options = options;
    this.type = type;
    this.proxyHost = proxyHost;
  }

  async getData(filterId) {
    const variables = {
      tenantId,
      condition: `type = '${this.type}'`,
      viewType: this.type
    };
    if (filterId) {
      variables.condition = `type = '${this.type}' AND id = '${filterId}'`;
    }

    const GQL_API_PATH = this.proxyHost + '/api/p/hdm_ea_uiapi';
    const res = await errorCheck(fetch(GQL_API_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Origin': window.location.origin },
      mode: 'cors',
      credentials: 'include',
      body: JSON.stringify({
        ...getQueries(this.options),
        variables
      })
    }));

    return await res.json();
  }
}

export default FilterViewAPI;
