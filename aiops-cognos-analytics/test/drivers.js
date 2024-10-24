/*
 * © Copyright IBM Corp. 2024
 *
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 */

const fs = require('fs');

/*
 * Drivers should have a connect, end, executeFile, formatTimestamp and query method.
 * Normalize to postgres standard.
 */
const drivers = {
  db2: (config) => {
    const db2 = require('ibm_db');
    const { normalizeResponse, stripComments } = require('./utils');
    const c = config;
    const connStr = `DATABASE=${c.database};HOSTNAME=${c.host};UID=${c.user};PWD=${c.password};PORT=${c.port};PROTOCOL=TCPIP`;
    let connection = null;
    return {
      connect: async () => { connection = await db2.open(connStr); },
      query: (str, params) => {
        let rows = [];
        if (connection) {
          rows = connection.querySync(str.replaceAll(/\$\d+/gi, '?'), params);
          rows = normalizeResponse(rows);
        }
        return { rows };
      },
      executeFile: (file, delim = '@') => {
        if (connection) {
          stripComments(file, file + 'clean');
          const res = connection.executeFileSync(file + 'clean', delim);
          fs.unlinkSync(file + 'clean');
          return res;
        }
      },
      end: async () => { if (connection) return await connection.close(); connection = null; },
      formatTimestamp: (timestamp) => {
        return timestamp.toString().replace('T', '-').replaceAll(':', '.').replace('Z', '000')
      }
    };
  }
};

module.exports = {
  getClient: (config) => {
    const client = drivers[config.client];
    if (client) {
      return client(config.connection);
    }
    throw new Error(`Unsupported client type: ${config.client}`);
  }
};
