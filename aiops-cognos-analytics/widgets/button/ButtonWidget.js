/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024, 2025
 *
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
import AlertSummaryAPI from '../common/AlertSummaryAPI';
import FilterViewAPI from '../common/FilterViewAPI';
import {conditionSetToAPIQuery, resolveQuery} from '../common/convertConditionSet';
import BaseRenderer from '../common/BaseRenderer';

class Renderer extends BaseRenderer {
  constructor(options) {
    super(options);
    this.content = options.content;
    this.contentId = this.content.getId();
    this.containerId = this.content.getContainer().getId();
    this.canvas = options.features['Dashboard.Canvas'];

    // Create the button element
    this.buttonElement = document.createElement('button');
    this.buttonElement.id = `${this.contentId}_button`;

    this.content.on('change:property', () => this.updateButtonProperties());
    this.alertSummaryTimer = null;
  }

  initialize() {
    super.initialize().then(() => {
      this.filterViewAPI = new FilterViewAPI({options: ['filter'], type: 'alert', proxyHost: this.proxyHost});
      this.alertSummaryAPI = new AlertSummaryAPI({groupBy: ['severity'], proxyHost: this.proxyHost});
    });
  }

  getAPI() {
    return {
      render: (domNode) => this.render(domNode)
    };
  }

  getMaxSeverity(data) {
    const severityArr = data?.data?.tenant?.alertSummary?.summary.map(group => group.severity);
    if (severityArr.length === 0) {
      return 0;
    }
    return Math.max(...severityArr);
  }

  getAlertCount(data) {
    return data?.data?.tenant?.alertSummary?.summary.reduce((total, group) => total + group.count, 0);
  }

  getSeverityColor(severity) {
    const colors = {
      1: '#B23AEE', 2: '#3f71b2', 3: '#408BFC', 4: '#FDD13A', 5: '#FC7B1E', 6: '#DA1E28'
    };
    return colors[severity] || '';
  }

  getButtonLabel(labelPropValue, filterName, alertCount) {
    if (labelPropValue === 'filterName') {
      return filterName;
    }
    if (labelPropValue === 'alertCount') {
      return alertCount;
    }
    return `${filterName} (${alertCount})`;
  }

  updatedButton({filterName, buttonShape, alertSummary}) {
    // get the max severity from the summary data
    const maxSeverity = this.getMaxSeverity(alertSummary);
    // set the alert count
    const alertCount = this.getAlertCount(alertSummary);
    const labelPropValue = this.content.getPropertyValue('dropdownButtonLabel');
    this.buttonElement.textContent = this.getButtonLabel(labelPropValue, filterName, alertCount);
    this.buttonElement.title = filterName;

    // color the button based on max severity
    this.buttonElement.className = buttonShape === 'round' ? 'aiops-button round' : 'aiops-button';
    let textColor = '#FFFFFF';
    if (maxSeverity < 1 || maxSeverity > 6) {
      textColor = '';
    }
    const style = `background-color: ${this.getSeverityColor(maxSeverity)}; border-color: ${this.getSeverityColor(maxSeverity)}; color: ${textColor}`;
    this.buttonElement.style = style;
  }

  compileWhereClause(whereClause) {
    try {
      return resolveQuery(whereClause);
    } catch (error) {
      console.error('Error compiling whereClause with handlebars:', error);
      return whereClause; // Return original whereClause if compilation fails
    }
  }

  async getAlertSummaryAndUpdateButton({filterId, buttonShape}) {
    // fetch the filter based on filterId
    const fetchedFilter = await this.filterViewAPI.getData(filterId);
    const filter = fetchedFilter?.data?.tenant?.filters[0];
    if (!filter) {
      this.buttonElement.title = 'Filter not found';
      return;
    }

    // convert the filter conditionSet to api query
    let apiQuery;
    if (filter.whereClause) {
      // Compile whereClause using handlebars if it exists
      apiQuery = this.compileWhereClause(filter.whereClause);
    } else {
      apiQuery = conditionSetToAPIQuery(filter.conditionSet);
    }

    // fetch alert summary for selected filter
    const alertSummary = await this.alertSummaryAPI.getData({filter: decodeURIComponent(apiQuery)});
    this.updatedButton({alertSummary, filterName: filter?.name, buttonShape});
  }

  async updateButtonProperties() {
    const buttonShape = this.content.getPropertyValue('dropdownShape');
    const refreshIntervalPropValue = Number(this.content.getPropertyValue('inputRefreshInterval'));
    let refreshInterval = 30;

    if (refreshIntervalPropValue && refreshIntervalPropValue >= 10) {
      refreshInterval = refreshIntervalPropValue;
    }

    this.content.getPropertyList().forEach(async (item) => {
      if (typeof item.getPropertyValue() !== 'undefined' && item.id === 'dropdownFilter') {
        const filterId = item.getPropertyValue();
        const propFilter = item.getFilter(filterId);
        const filterCondition = propFilter?.conditionSet;

        try {
          if (!filterCondition) {
            this.buttonElement.title = 'Filter not found';
          } else {
            await this.getAlertSummaryAndUpdateButton({filterId, buttonShape});
            if (this.alertSummaryTimer) {
              clearInterval(this.alertSummaryTimer);
            }

            this.alertSummaryTimer = setInterval(async () => {
              await this.getAlertSummaryAndUpdateButton({filterId, buttonShape});
            }, refreshInterval * 1000);
          }
          this.buttonElement.onclick = () => this.handleButtonClick(propFilter.label);
        } catch (ex) {
          console.log(ex);
        }
      }
    });
  }

  handleButtonClick(filterName) {
    const targetPropValue = this.content.getPropertyValue('dropdownTarget');
    if (targetPropValue === 'update') {
      window.postMessage({ containerId: this.containerId, source: 'dashboard', params: { filtername: filterName } }, window.location.origin);
    } else {
      window.open(`${this.proxyHost}/aiops/default/resolution-hub/alerts?filtername=${filterName}`);
    }
  }

  renderControl() {
    this.parentNode.appendChild(this.buttonElement);
  }

  render(options) {
    this.parentNode = options.parent;
    this.renderControl();
    this.updateButtonProperties();

    return Promise.resolve();
  }
}

export default Renderer;
