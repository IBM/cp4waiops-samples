define(["exports"], function (_exports) {
  "use strict";

  Object.defineProperty(_exports, "__esModule", {
    value: true
  });
  _exports.errorCheck = void 0;
  /* ******************************************************** {COPYRIGHT-TOP} ****
   * IBM Confidential
   * 5725-Q09, 5737-M96
   * © Copyright IBM Corp. 2024
   ********************************************************* {COPYRIGHT-END} ****/
  const FETCH_ERROR = 'FETCH_ERROR';
  const FETCH_ERROR_400 = 'FETCH_ERROR_400';
  const FETCH_ERROR_401 = 'FETCH_ERROR_401';
  const FETCH_ERROR_403 = 'FETCH_ERROR_403';
  const FETCH_ERROR_500 = 'FETCH_ERROR_500';
  const errorCheck = async fetchPromise => {
    let response;
    try {
      response = await fetchPromise;
    } catch (e) {
      console.error(e);
    }
    if (!response.ok) {
      let responseText;
      try {
        responseText = response.text();
      } catch (e) {
        // Ignore failure
      }
      let errType;
      if (response.status >= 400 && response.status < 500) {
        switch (response.status) {
          case 401:
            errType = FETCH_ERROR_401;
            break;
          case 403:
            errType = FETCH_ERROR_403;
            break;
          default:
            errType = FETCH_ERROR_400;
            break;
        }
      } else if (response.status >= 500 && response.status < 600) {
        errType = FETCH_ERROR_500;
      } else {
        errType = FETCH_ERROR;
      }
      console.log('HDM_EA_UIAPI_ERROR', errType, {
        status: response.status,
        url: response.url,
        responseText
      });
    }
    return response;
  };
  _exports.errorCheck = errorCheck;
});
//# sourceMappingURL=apiErrorCheck.js.map