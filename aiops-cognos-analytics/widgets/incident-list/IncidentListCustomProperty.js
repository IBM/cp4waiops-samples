/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024
 * 
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
import FilterViewAPI from '../common/FilterViewAPI';
import BaseRenderer from '../common/BaseRenderer';

const TYPE = 'story';
const defaultFilter = 'All incidents';
const defaultView = 'Default View';
let filtersViewsResult = [];

async function getViews(proxyHost) {
  const filterViewAPI = new FilterViewAPI({options: ['filter', 'view'], type: TYPE, proxyHost});
  filtersViewsResult = await filterViewAPI.getData();
}

class IncidentListDynamicProperty extends BaseRenderer {
  constructor(options) {
    super(options);
    options.features.Properties.registerProvider(this);
  }

  initialize() {
    super.initialize()
      .then(() => {
        return getViews(this.proxyHost);
      });
  }

  getPropertyList() {
    const filters = [];
    filtersViewsResult.data?.tenant.filters.forEach(filter => {
      filters.push({'label': filter.name, 'value': filter.name});
    });

    const views = [];
    filtersViewsResult.data?.tenant.views.forEach(view => {
      views.push({'label': view.name, 'value': view.name});
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

export default IncidentListDynamicProperty;
