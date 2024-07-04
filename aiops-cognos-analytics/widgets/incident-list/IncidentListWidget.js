define(["exports"], function (_exports) {
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
  class Renderer {
    constructor(options) {
      this.content = options.content;
      this.iframeId = `${this.content.getId()}_incidentListWidget`;
      this.containerId = this.content.getContainer().getId();
      this.canvas = options.features['Dashboard.Canvas'];
      this.canvas.on('change:content:selections', payload => {
        const contentID = payload.info.events[0].info.contentId;
        const containerId = document.getElementById(contentID).parentNode.id;
        const dataPointSelection = this.canvas.getContent(contentID).getFeature('DataPointSelections');
        let inputColumnMapping;
        this.content.getPropertyList().forEach(item => {
          if (item.id === 'inputColumnMapping') {
            inputColumnMapping = item.getPropertyValue();
          }
        });
        const getColumnMapping = value => {
          try {
            return JSON.parse(value);
          } catch (ex) {
            return value;
          }
        };
        if (containerId === this.containerId) {
          inputColumnMapping = getColumnMapping(inputColumnMapping);
          const iframeIncidentListWidget = document.getElementById(this.iframeId);
          iframeIncidentListWidget?.contentWindow.postMessage({
            source: 'dashboard',
            params: {
              widgetdata: dataPointSelection.getSelections(),
              transformations: {
                columnmapping: inputColumnMapping
              }
            }
          }, '*');
        }
      });
      this.content.on('change:property', data => {
        const iframeIncidentListWidget = document.getElementById(this.iframeId);
        if (data?.info?.events[0].name === 'change:property:dropdownView') {
          const viewName = data?.info?.events[0].info.value;
          iframeIncidentListWidget.contentWindow.postMessage({
            source: 'dashboard',
            params: {
              viewname: viewName
            }
          }, window.location.origin);
        }
        if (data?.info?.events[0].name === 'change:property:toggleToolbar') {
          const showToolbar = data?.info?.events[0].info.value;
          iframeIncidentListWidget.contentWindow.postMessage({
            source: 'dashboard',
            params: {
              showtoolbar: showToolbar
            }
          }, window.location.origin);
        }
        if (data?.info?.events[0].name === 'change:property:toggleDetails') {
          const showDetails = data?.info?.events[0].info.value;
          iframeIncidentListWidget.contentWindow.postMessage({
            source: 'dashboard',
            params: {
              showdetails: showDetails
            }
          }, window.location.origin);
        }
        if (data?.info?.events[0].name === 'change:property:inputColumnMapping') {
          let columnMapping = data?.info?.events[0].info.value;
          const getColumnMapping = value => {
            try {
              return JSON.parse(value);
            } catch (ex) {
              return value;
            }
          };
          columnMapping = getColumnMapping(columnMapping);
          iframeIncidentListWidget.contentWindow.postMessage({
            source: 'dashboard',
            params: {
              transformations: {
                columnmapping: {
                  columnMapping
                }
              }
            }
          }, window.location.origin);
        }
      });
    }
    getAPI() {
      return {
        render: domNode => this.render(domNode)
      };
    }
    destroy() {}
    renderControl() {
      let viewName = '';
      let showToolbar = true;
      let showDetails = false;
      this.content.getPropertyList().forEach(item => {
        if (typeof item.getPropertyValue() !== 'undefined' && item.id === 'dropdownView') {
          viewName = item.getPropertyValue();
          viewName = viewName.replace(/ /g, '+');
        } else if (typeof item.getPropertyValue() !== 'undefined' && item.id === 'toggleToolbar') {
          showToolbar = item.getPropertyValue();
        } else if (typeof item.getPropertyValue() !== 'undefined' && item.id === 'toggleDetails') {
          showDetails = item.getPropertyValue();
        }
      });
      this.parentNode.innerHTML = "<iframe id='" + this.iframeId + "' src='https://" + window.location.host + '/aiops/default/widgets/incidents?showtoolbar=' + showToolbar + '&showdetails=' + showDetails + '&viewname=' + viewName + '&containerid=' + this.containerId + "' title='AIOPS Incident List widget' frameBorder='0' width='100%' height='100%'></iframe>";
    }
    render(options) {
      this.parentNode = options.parent;
      this.renderControl();
      return Promise.resolve();
    }
  }
  var _default = _exports.default = Renderer;
});
//# sourceMappingURL=IncidentListWidget.js.map