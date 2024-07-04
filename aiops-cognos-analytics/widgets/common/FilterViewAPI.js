define(["exports", "./apiErrorCheck"], function (_exports, _apiErrorCheck) {
  "use strict";

  Object.defineProperty(_exports, "__esModule", {
    value: true
  });
  _exports.default = void 0;
  /* ******************************************************** {COPYRIGHT-TOP} ****
   * IBM Confidential
   * 5725-Q09, 5737-M96
   * © Copyright IBM Corp. 2024
   ********************************************************* {COPYRIGHT-END} ****/

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
    options = [];
    // type can be either 'alert' or 'story
    type = null;
    constructor({
      options,
      type
    }) {
      this.options = options;
      this.type = type;
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
      const GQL_API_PATH = '/api/p/hdm_ea_uiapi';
      const res = await (0, _apiErrorCheck.errorCheck)(fetch(GQL_API_PATH, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          ...getQueries(this.options),
          variables
        })
      }));
      return await res.json();
    }
  }
  var _default = _exports.default = FilterViewAPI;
});
//# sourceMappingURL=FilterViewAPI.js.map