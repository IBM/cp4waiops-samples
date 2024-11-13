/*
 * © Copyright IBM Corp. 2024
 *
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 */

module.exports = {
  stripComments: (inFile, outFile) => {
    const fs = require('fs');
    try {
      // read file into a string
      const contents = fs.readFileSync(inFile, 'utf-8');
      const updated = contents.replaceAll(/\s*--.*/gi, '');
      fs.writeFileSync(outFile || inFile, updated, 'utf-8');
    } catch (err) {
      console.error(err);
    }
  },
  normalizeResponse: (res) => {
    if (Array.isArray(res)) {
      return res.map(module.exports.normalizeResponse);
    }
    if (typeof res === 'object') {
      // lowercase keys
      const normalized = Object.keys(res).reduce((obj, key) => {
        obj[key.toLowerCase()] = res[key];
        return obj;
      }, {});

      // date/time values as js dates
      Object.keys(normalized).forEach(k => {
        if (/(date|time)/i.test(k)) {
          try {
            if (normalized[k]) {
              normalized[k] = new Date(normalized[k]);
              normalized[k].setMilliseconds(0);
            }
          } catch (e) {}
        }
      });

      return normalized;
    }
    return res;
  }
};
