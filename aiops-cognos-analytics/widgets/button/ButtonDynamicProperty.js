/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024
 * 
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
import FilterViewAPI from '../common/FilterViewAPI';
import BaseRenderer from '../common/BaseRenderer';

const TYPE = 'alert';
let filtersViewsResult = [];

async function getFilters(proxyHost) {
  const filterViewAPI = new FilterViewAPI({options: ['filter'], type: TYPE, proxyHost});
  filtersViewsResult = await filterViewAPI.getData();
  return Promise.resolve();
}

class ButtonDynamicProperty extends BaseRenderer {
  constructor(options) {
    super(options);
    options.features.Properties.registerProvider(this);
  }

  initialize() {
    super.initialize()
      .then(() => {
        return getFilters(this.proxyHost);
      });
  }

  getPropertyList() {
    const filters = [];
    filtersViewsResult.data?.tenant.filters.forEach(filter => {
      filters.push({label: filter.name, value: filter.id, conditionSet: filter.conditionSet });
    });

    return [
      {
        'id': 'dropdownFilter',
        'defaultValue': filters?.[0]?.value,
        getFilter: (filterId) => {
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

export default ButtonDynamicProperty;
