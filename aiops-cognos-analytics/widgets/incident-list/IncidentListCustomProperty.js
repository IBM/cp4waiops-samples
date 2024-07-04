define(["exports", "../common/FilterViewAPI"], function (_exports, _FilterViewAPI) {
  "use strict";

  Object.defineProperty(_exports, "__esModule", {
    value: true
  });
  _exports.default = void 0;
  _FilterViewAPI = _interopRequireDefault(_FilterViewAPI);
  function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }
  /* ******************************************************** {COPYRIGHT-TOP} ****
   * IBM Confidential
   * 5725-Q09, 5737-M96
   * © Copyright IBM Corp. 2024
   ********************************************************* {COPYRIGHT-END} ****/

  const TYPE = 'story';
  const defaultView = 'Default View';
  let filtersViewsResult = [];
  async function getViews() {
    const filterViewAPI = new _FilterViewAPI.default({
      options: ['view'],
      type: TYPE
    });
    filtersViewsResult = await filterViewAPI.getData();
  }
  class IncidentListDynamicProperty {
    constructor(options) {
      getViews();
      options.features.Properties.registerProvider(this);
    }
    getPropertyList() {
      const views = [];
      filtersViewsResult.data?.tenant.views.forEach(view => {
        views.push({
          'label': view.name,
          'value': view.name
        });
      });
      return [{
        'id': 'dropdownView',
        'defaultValue': defaultView,
        'editor': {
          'sectionId': 'general.aiops_settings',
          'uiControl': {
            'type': 'DropDown',
            'name': 'dropdown View',
            'label': 'View',
            'ariaLabel': 'View',
            'options': views
          }
        }
      }];
    }
    getPropertyLayoutList() {
      return [];
    }
  }
  var _default = _exports.default = IncidentListDynamicProperty;
});
//# sourceMappingURL=IncidentListCustomProperty.js.map