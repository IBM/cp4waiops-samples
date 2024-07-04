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
    constructor({
      groupBy
    }) {
      this.groupBy = groupBy;
    }
    async getData({
      filter = ''
    }) {
      const GQL_API_PATH = '/api/p/hdm_ea_uiapi';
      const res = await (0, _apiErrorCheck.errorCheck)(fetch(GQL_API_PATH, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
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
  var _default = _exports.default = AlertSummaryAPI;
});
//# sourceMappingURL=AlertSummaryAPI.js.map