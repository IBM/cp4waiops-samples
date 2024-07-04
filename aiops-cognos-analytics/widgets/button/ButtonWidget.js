define(["exports", "../common/AlertSummaryAPI", "../common/FilterViewAPI", "../common/convertConditionSet"], function (_exports, _AlertSummaryAPI, _FilterViewAPI, _convertConditionSet) {
  "use strict";

  Object.defineProperty(_exports, "__esModule", {
    value: true
  });
  _exports.default = void 0;
  _AlertSummaryAPI = _interopRequireDefault(_AlertSummaryAPI);
  _FilterViewAPI = _interopRequireDefault(_FilterViewAPI);
  function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }
  /* ******************************************************** {COPYRIGHT-TOP} ****
   * IBM Confidential
   * 5725-Q09, 5737-M96
   * © Copyright IBM Corp. 2024
   ********************************************************* {COPYRIGHT-END} ****/

  class Renderer {
    constructor(options) {
      this.content = options.content;
      this.contentId = this.content.getId();
      this.containerId = this.content.getContainer().getId();
      this.canvas = options.features['Dashboard.Canvas'];

      // Create the button element
      this.buttonElement = document.createElement('button');
      this.buttonElement.id = `${this.contentId}_button`;
      this.content.on('change:property', () => this.updateButtonProperties());
      this.alertSummaryTimer = null;
      this.filterViewAPI = new _FilterViewAPI.default({
        options: ['filter'],
        type: 'alert'
      });
      this.alertSummaryAPI = new _AlertSummaryAPI.default({
        groupBy: ['severity']
      });
    }
    getAPI() {
      return {
        render: domNode => this.render(domNode)
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
        1: '#B23AEE',
        2: '#3f71b2',
        3: '#408BFC',
        4: '#FDD13A',
        5: '#FC7B1E',
        6: '#DA1E28'
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
    updatedButton({
      filterName,
      buttonShape,
      alertSummary
    }) {
      // get the max severity from the summary data
      const maxSeverity = this.getMaxSeverity(alertSummary);
      // set the alert count
      const alertCount = this.getAlertCount(alertSummary);
      const labelPropValue = this.content.getPropertyValue('dropdownButtonLabel');
      // this.buttonElement.textContent = labelOption === 'alertCount' ? `${alertCount}` : buttonLabel;
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
    async getAlertSummaryAndUpdateButton({
      filterId,
      buttonShape
    }) {
      // fetch the filter based on filterId
      const fetchedFilter = await this.filterViewAPI.getData(filterId);
      const filter = fetchedFilter?.data?.tenant?.filters[0];
      if (!filter) {
        this.buttonElement.title = 'Filter not found';
      }
      // convert the filter conditionSet to api query
      const apiQuery = (0, _convertConditionSet.conditionSetToAPIQuery)(filter.conditionSet);
      // fetch alert summary for selected filter
      const alertSummary = await this.alertSummaryAPI.getData({
        filter: decodeURIComponent(apiQuery)
      });
      this.updatedButton({
        alertSummary,
        filterName: filter?.name,
        buttonShape
      });
    }
    async updateButtonProperties() {
      const buttonShape = this.content.getPropertyValue('dropdownShape');
      const refreshIntervalPropValue = Number(this.content.getPropertyValue('inputRefreshInterval'));
      let refreshInterval = 30;
      if (refreshIntervalPropValue && refreshIntervalPropValue >= 10) {
        refreshInterval = refreshIntervalPropValue;
      }
      this.content.getPropertyList().forEach(async item => {
        if (typeof item.getPropertyValue() !== 'undefined' && item.id === 'dropdownFilter') {
          const filterId = item.getPropertyValue();
          const propFilter = item.getFilter(filterId);
          const filterCondition = propFilter.conditionSet;
          try {
            if (!filterCondition) {
              this.buttonElement.title = 'Filter not found';
            } else {
              await this.getAlertSummaryAndUpdateButton({
                filterId,
                buttonShape
              });
              if (this.alertSummaryTimer) {
                clearInterval(this.alertSummaryTimer);
              }
              this.alertSummaryTimer = setInterval(async () => {
                await this.getAlertSummaryAndUpdateButton({
                  filterId,
                  buttonShape
                });
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
        window.postMessage({
          containerId: this.containerId,
          source: 'dashboard',
          params: {
            filtername: filterName
          }
        }, window.location.origin);
      } else {
        window.open(`${window.location.origin}/aiops/default/resolution-hub/alerts?filtername=${filterName}`);
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
  var _default = _exports.default = Renderer;
});
//# sourceMappingURL=ButtonWidget.js.map