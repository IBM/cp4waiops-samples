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
  let filtersViewsResult = [];
  async function getFilters() {
    const filterViewAPI = new _FilterViewAPI.default({
      options: ['filter'],
      type: TYPE
    });
    filtersViewsResult = await filterViewAPI.getData();
    return Promise.resolve();
  }
  class ButtonDynamicProperty {
    constructor(options) {
      options.features.Properties.registerProvider(this);
    }
    initialize() {
      // this will make sure the promise is resolved before initializing property list
      return getFilters();
    }
    getPropertyList() {
      const filters = [];
      filtersViewsResult.data?.tenant.filters.forEach(filter => {
        filters.push({
          label: filter.name,
          value: filter.id,
          conditionSet: filter.conditionSet
        });
      });
      return [{
        'id': 'dropdownFilter',
        'defaultValue': filters?.[0]?.value,
        getFilter: filterId => {
          return filters.find(f => f.value === filterId);
        },
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
      }
      // {
      //   'id': 'sliderRefreshInterval',
      //   'type': '../UiSlider',
      //   'module': '../ui/UiSlider',
      //   'label': 'Refresh interval',
      //   'active': true,
      //   'connect': [true, false],
      //   'setp': 1,
      //   'start': [10],
      //   'range': {
      //     'min': 10,
      //     'max': 60
      //   }
      // }
      ];
    }
    getPropertyLayoutList() {
      return [];
    }
  }
  var _default = _exports.default = ButtonDynamicProperty;
});
//# sourceMappingURL=ButtonDynamicProperty.js.map