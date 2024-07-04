define(["exports"], function (_exports) {
  "use strict";

  Object.defineProperty(_exports, "__esModule", {
    value: true
  });
  _exports.default = void 0;
  /* ******************************************************** {COPYRIGHT-TOP} ****
   * IBM Confidential
   * 5725-Q09, 5737-M96
   * © Copyright IBM Corp. 2023, 2024
   ********************************************************* {COPYRIGHT-END} ****/
  class Renderer {
    constructor(options) {
      this.content = options.content;
      this.iframeId = `${this.content.getId()}_topologyWidget`;
      this.containerId = this.content.getContainer().getId();
      this.canvas = options.features['Dashboard.Canvas'];
      this.canvas.on('change:content:selections', payload => {
        const contentID = payload.info.events[0].info.contentId;
        const containerId = document.getElementById(contentID).parentNode.id;
        const dataPointSelection = this.canvas.getContent(contentID).getFeature('DataPointSelections');
        if (containerId === this.containerId) {
          const iframeTopoWidget = document.getElementById(this.iframeId);
          iframeTopoWidget.contentWindow.postMessage({
            'source': 'dashboard',
            params: {
              widgetdata: dataPointSelection.getSelections()
            }
          }, '*');
        }
      });
      this.messageHandler = ({
        data
      }) => {
        if (data.containerId === this.containerId) {
          document.getElementById(this.iframeId).contentWindow.postMessage(data, '*');
        }
      };
      this.content.on('change:property', data => {
        const iframeTopoWidget = document.getElementById(this.iframeId);
        if (data?.info?.events[0].name === 'change:property:hops') {
          const hops = data?.info?.events[0].info.value;
          iframeTopoWidget.contentWindow.postMessage({
            'source': 'dashboard',
            params: {
              hops: hops
            }
          }, '*');
        }
        if (data?.info?.events[0].name === 'change:property:maxResourceIds') {
          const maxResourceIds = data?.info?.events[0].info.value;
          iframeTopoWidget.contentWindow.postMessage({
            'source': 'dashboard',
            params: {
              maxResourceIds: maxResourceIds
            }
          }, '*');
        }
        if (data?.info?.events[0].name === 'change:property:toggleToolbar') {
          const showToolbar = data?.info?.events[0].info.value;
          iframeTopoWidget.contentWindow.postMessage({
            'source': 'dashboard',
            params: {
              hideToolbar: !showToolbar
            }
          }, '*');
        }
        if (data?.info?.events[0].name === 'change:property:toggleSearch') {
          const showSearch = data?.info?.events[0].info.value;
          iframeTopoWidget.contentWindow.postMessage({
            'source': 'dashboard',
            params: {
              hideSearch: !showSearch
            }
          }, '*');
        }
        if (data?.info?.events[0].name === 'change:property:resourceId') {
          const resourceId = data?.info?.events[0].info.value;
          iframeTopoWidget.contentWindow.postMessage({
            'source': 'dashboard',
            params: {
              transformations: {
                resourceId: resourceId
              }
            }
          }, '*');
        }
        if (data?.info?.events[0].name === 'change:property:statusId') {
          const statusId = data?.info?.events[0].info.value;
          iframeTopoWidget.contentWindow.postMessage({
            'source': 'dashboard',
            params: {
              transformations: {
                statusId: statusId
              }
            }
          }, '*');
        }

        // this.renderControl();
      });
      window.addEventListener('message', this.messageHandler, false);
    }
    getAPI() {
      return {
        render: domNode => this.render(domNode)
      };
    }
    destroy() {
      window.removeEventListener('message', this.messageHandler, false);
    }
    renderControl() {
      this.parentNode.innerHTML = "<iframe id='" + this.iframeId + "' src='https://" + window.location.host + '/aiops/cfd95b7e-3bc7-4006-a4a8-a73a79c71255/widgets/topology-viewer?containerid=' + this.containerId + "' frameBorder='0' title='AIOPS Topology widget' width='100%' height='100%'></iframe>";
    }
    render(options) {
      this.parentNode = options.parent;
      this.renderControl();
      return Promise.resolve();
    }
  }
  var _default = _exports.default = Renderer;
});
//# sourceMappingURL=TopologyViewerWidget.js.map