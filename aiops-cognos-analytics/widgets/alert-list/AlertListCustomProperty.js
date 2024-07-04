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

  const TYPE = 'alert';
  const defaultView = 'Default View';
  const defaultFilter = 'All alerts';
  let filtersViewsResult = [];
  async function getFiltersAndViews() {
    const filterViewAPI = new _FilterViewAPI.default({
      options: ['filter', 'view'],
      type: TYPE
    });
    filtersViewsResult = await filterViewAPI.getData();
  }
  class AlertListDynamicProperty {
    constructor(options) {
      getFiltersAndViews();
      options.features.Properties.registerProvider(this);
    }
    getPropertyList() {
      const filters = [];
      filtersViewsResult.data?.tenant.filters.forEach(filter => {
        filters.push({
          'label': filter.name,
          'value': filter.name
        });
      });
      const views = [];
      filtersViewsResult.data?.tenant.views.forEach(view => {
        views.push({
          'label': view.name,
          'value': view.name
        });
      });
      return [{
        'id': 'dropdownFilter',
        'defaultValue': defaultFilter,
        'editor': {
          'sectionId': 'general.aiops_settings',
          'uiControl': {
            'type': 'DropDown',
            'name': 'dropdown Filter',
            'label': 'Filter',
            'ariaLabel': 'Filter',
            'options': filters
          }
        }
      }, {
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
  var _default = _exports.default = AlertListDynamicProperty;
});
//# sourceMappingURL=AlertListCustomProperty.js.map