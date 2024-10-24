/*
 * © Copyright IBM Corp. 2024
 *
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 */

const expect = require('chai').expect;
const nconf = require('nconf');
const path = require('path');
const fs = require('fs');
const drivers = require('./drivers');

nconf.argv().env('__')
nconf.file('test', `${path.resolve(__dirname)}/config.json`);
const config = nconf.get();
const schemaPath = '../schemas/' + config.client;
let client = null;

describe('Schema test', () => {
  before(async () => {
    client = drivers.getClient(config);
    return await client.connect();
  });

  after(async () => {
    return await client.end();
  });

  describe('Alerts', () => {
    before(async () => {
      return await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_alerts.sql'));
    });

    after(async () => {
      return await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_alerts_remove.sql'));
    });

    it('should have the correct columns', async () => {
      const results = await client.query(`SELECT distinct(name) FROM sysibm.syscolumns WHERE tbname = 'ALERTS_REPORTER_STATUS'`);
      const columnNames = results.rows.map((result) => result.name.toLowerCase());
      expect(columnNames).to.eql([
        'acknowledged',
        'anomalyinsights',
        'businesscriticality',
        'deduplicationkey',
        'eventcount',
        'eventtype',
        'expiryseconds',
        'firstoccurrencetime',
        'goldensignal',
        'id',
        'incidentcontrol',
        'inincident',
        'langid',
        'lastoccurrencetime',
        'laststatechangetime',
        'owner',
        'resolutions',
        'resource',
        'runbooks',
        'scopegroup',
        'seasonal',
        'sender',
        'severity',
        'signature',
        'state',
        'subtopology',
        'summary',
        'suppressed',
        'team',
        'templates',
        'temporal',
        'tenantid',
        'topology',
        'triggeralert',
        'uuid'
      ]);
    });

    it('should audit acknowledged and severity on new alert', async () => {
      const auditAckRes = {
        acknowledged: 0,
        laststatechangetime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: null,
        owner: '-',
        state: 0,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'
      };
      const auditSevRes = {
        laststatechangetime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: null,
        severity: 5,
        state: 0,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'
      };

      const mockDate = client.formatTimestamp('2024-09-10T18:21:46.000Z');
      const queryString = fs.readFileSync(path.resolve(__dirname, './insert-alert.sql'), 'utf8');
      await client.query(queryString, [mockDate, mockDate, mockDate]);

      // ack record
      let res = await client.query('SELECT * FROM ALERTS_AUDIT_ACK');
      expect(res.rows[0]).to.eql(auditAckRes);

      // sev record
      res = await client.query('SELECT * FROM ALERTS_AUDIT_SEVERITY');
      expect(res.rows[0]).to.eql(auditSevRes);
    });

    it('should audit severity update', async () => {
      const previousSev = {
        laststatechangetime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: new Date('2024-09-10T23:21:46.000Z'),
        severity: 5,
        state: 1,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'
      };
      const newSev = {
        laststatechangetime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: null,
        severity: 4,
        state: 0,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'
      };

      await client.query(`UPDATE ALERTS_REPORTER_STATUS SET severity = 4 WHERE id = 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'`);

      // sev records (1 from alert creation, 1 from severity update)
      res = await client.query('SELECT * FROM ALERTS_AUDIT_SEVERITY');
      expect(res.rows[0]).to.eql(previousSev);
      expect(res.rows[1]).to.eql(newSev);
    });

    it('should audit acknowledged update', async () => {
      const previousAck = {
        laststatechangetime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: new Date('2024-09-10T23:21:46.000Z'),
        acknowledged: 0,
        owner: '-',
        state: 1,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'
      };
      const newAck = {
        laststatechangetime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: null,
        acknowledged: 1,
        owner: '-',
        state: 0,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'
      };

      await client.query(`UPDATE ALERTS_REPORTER_STATUS SET acknowledged = 1 WHERE id = 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'`);

      // sev records (1 from alert creation, 1 from acknowledged update)
      res = await client.query('SELECT * FROM ALERTS_AUDIT_ACK');
      expect(res.rows[0]).to.eql(previousAck);
      expect(res.rows[1]).to.eql(newAck);
    });

    it('should audit owner update', async () => {
      const ownerRes = {
        laststatechangetime: new Date('2024-09-10T23:21:46.000Z'),
        oldowner: '-',
        owner: 'joeblow',
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'
      };

      await client.query(`UPDATE ALERTS_REPORTER_STATUS SET owner = 'joeblow' WHERE id = 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'`);

      // owner record (no previous owner record)
      res = await client.query('SELECT * FROM ALERTS_AUDIT_OWNER');
      expect(res.rows[0]).to.eql(ownerRes);
    });

    it('should audit team update', async () => {
      const teamRes = {
        laststatechangetime: new Date('2024-09-10T23:21:46.000Z'),
        oldteam: '-',
        team: 'teamusa',
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'
      };

      await client.query(`UPDATE ALERTS_REPORTER_STATUS SET team = 'teamusa' WHERE id = 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'`);

      // team record (no previous team record)
      res = await client.query('SELECT * FROM ALERTS_AUDIT_TEAM');
      expect(res.rows[0]).to.eql(teamRes);
    });
  });

  describe('Incidents', () => {
    before(async () => {
      return await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_incidents.sql'));
    });

    after(async () => {
      return await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_incidents_remove.sql'));
    });

    it('should have the correct columns', async () => {
      const results = await client.query(`SELECT distinct(name) FROM sysibm.syscolumns WHERE tbname = 'INCIDENTS_REPORTER_STATUS'`);
      const columnNames = results.rows.map((result) => result.name.toLowerCase());
      expect(columnNames).to.eql([
        'alerts',
        'chatopsintegrations',
        'createdby',
        'createdtime',
        'description',
        'id',
        'langid',
        'lastchangedtime',
        'owner',
        'policyid',
        'priority',
        'probablecausealerts',
        'resourceid',
        'similarincidents',
        'splitincidents',
        'state',
        'team',
        'tenantid',
        'tickets',
        'title',
        'uuid'
      ]);
    });

    it('should audit state and priority on new incident', async () => {
      const auditStateRes =  {
        state: 'unassigned',
        lastchangedtime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: null,
        owner: '-',
        complete: 0,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: '24fba2e3-0000-4000-8000-000000000002',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_24fba2e3-0000-4000-8000-000000000002'
      };
      const auditPriRes = {
        lastchangedtime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: null,
        priority: 1,
        complete: 0,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: '24fba2e3-0000-4000-8000-000000000002',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_24fba2e3-0000-4000-8000-000000000002'
      };

      const mockDate = client.formatTimestamp('2024-09-10T18:21:46.000Z');
      const queryString = fs.readFileSync(path.resolve(__dirname, './insert-incident.sql'), 'utf8');
      await client.query(queryString, [mockDate, mockDate]);

      // state record
      let res = await client.query('SELECT * FROM INCIDENTS_AUDIT_STATE');
      expect(res.rows[0]).to.eql(auditStateRes);

      // priority record
      res = await client.query('SELECT * FROM INCIDENTS_AUDIT_PRIORITY');
      expect(res.rows[0]).to.eql(auditPriRes);
    });

    it('should audit priority update', async () => {
      const oldPriority = {
        lastchangedtime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: new Date('2024-09-10T23:21:46.000Z'),
        priority: 1,
        complete: 1,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: '24fba2e3-0000-4000-8000-000000000002',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_24fba2e3-0000-4000-8000-000000000002'
      };
      const newPriority = {
        lastchangedtime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: null,
        priority: 2,
        complete: 0,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: '24fba2e3-0000-4000-8000-000000000002',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_24fba2e3-0000-4000-8000-000000000002'
      };

      await client.query(`UPDATE INCIDENTS_REPORTER_STATUS SET priority = 2 WHERE id = '24fba2e3-0000-4000-8000-000000000002'`);

      // priority records (1 from incident creation, 1 from priority update)
      res = await client.query('SELECT * FROM INCIDENTS_AUDIT_PRIORITY');
      expect(res.rows[0]).to.eql(oldPriority);
      expect(res.rows[1]).to.eql(newPriority);
    });

    it('should audit state update', async () => {
      const oldState = {
        lastchangedtime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: new Date('2024-09-10T23:21:46.000Z'),
        state: 'unassigned',
        owner: '-',
        complete: 1,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: '24fba2e3-0000-4000-8000-000000000002',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_24fba2e3-0000-4000-8000-000000000002'
      };
      const newState = {
        lastchangedtime: new Date('2024-09-10T23:21:46.000Z'),
        enddate: null,
        state: 'inProgress',
        owner: '-',
        complete: 0,
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: '24fba2e3-0000-4000-8000-000000000002',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_24fba2e3-0000-4000-8000-000000000002'
      };

      await client.query(`UPDATE INCIDENTS_REPORTER_STATUS SET state = 'inProgress' WHERE id = '24fba2e3-0000-4000-8000-000000000002'`);

      // state records (1 from incident creation, 1 from state update)
      res = await client.query('SELECT * FROM INCIDENTS_AUDIT_STATE');
      expect(res.rows[0]).to.eql(oldState);
      expect(res.rows[1]).to.eql(newState);
    });

    it('should audit owner update', async () => {
      const ownerRes = {
        lastchangedtime: new Date('2024-09-10T23:21:46.000Z'),
        oldowner: '-',
        owner: 'joeblow',
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: '24fba2e3-0000-4000-8000-000000000002',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_24fba2e3-0000-4000-8000-000000000002'
      };

      await client.query(`UPDATE INCIDENTS_REPORTER_STATUS SET owner = 'joeblow' WHERE id = '24fba2e3-0000-4000-8000-000000000002'`);

      // owner record (no previous owner record)
      res = await client.query('SELECT * FROM INCIDENTS_AUDIT_OWNER');
      expect(res.rows[0]).to.eql(ownerRes);
    });

    it('should audit team update', async () => {
      const teamRes = {
        lastchangedtime: new Date('2024-09-10T23:21:46.000Z'),
        oldteam: '-',
        team: 'teamusa',
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: '24fba2e3-0000-4000-8000-000000000002',
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_24fba2e3-0000-4000-8000-000000000002'
      };

      await client.query(`UPDATE INCIDENTS_REPORTER_STATUS SET team = 'teamusa' WHERE id = '24fba2e3-0000-4000-8000-000000000002'`);

      // team record (no previous team record)
      res = await client.query('SELECT * FROM INCIDENTS_AUDIT_TEAM');
      expect(res.rows[0]).to.eql(teamRes);
    });
  });

  describe('Noise reduction', () => {
    before(async () => {
      await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_alerts.sql'));
      await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_incidents.sql'));
      await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_noise_reduction.sql'));
    });

    after(async () => {
      await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_noise_reduction_remove.sql'));
      await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_incidents_remove.sql'));
      await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_alerts_remove.sql'));
    });

    it('should have the correct columns', async () => {
      const results = await client.query(`SELECT distinct(name) FROM sysibm.syscolumns WHERE tbname = 'INCIDENT_DASHBOARD'`);
      const columnNames = results.rows.map((result) => result.name.toLowerCase());
      expect(columnNames).to.eql([
        'alertcount',
        'criticalpct',
        'eventcount',
        'incidentcount',
        'inprogresscount',
        'ticketedcount',
        'unassignedcount'
      ]);
    });

    it('should update counts on new alert', async () => {
      const counts =  {
        eventcount: '200',
        alertcount: '1',
        incidentcount: null
      };

      const mockDate = client.formatTimestamp('2024-09-10T18:21:46.000Z');
      const queryString = fs.readFileSync(path.resolve(__dirname, './insert-alert.sql'), 'utf8');
      await client.query(queryString, [mockDate, mockDate, mockDate]);

      const res = await client.query('SELECT * FROM INCIDENT_DASHBOARD ORDER BY eventCount');
      Object.keys(counts).forEach(c => expect(res.rows[0]).to.have.property(c, counts[c]));
    });

    it('should update counts on updated alert', async () => {
      const counts =  {
        eventcount: '400',
        alertcount: '1',
        incidentcount: null
      };

      await client.query(`UPDATE ALERTS_REPORTER_STATUS SET eventCount = 400 WHERE id = 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'`);

      const res = await client.query('SELECT * FROM INCIDENT_DASHBOARD ORDER BY eventCount');
      Object.keys(counts).forEach(c => expect(res.rows[0]).to.have.property(c, counts[c]));
    });

    it('should update counts on new incident', async () => {
      const alertCounts =  {
        eventcount: '400',
        alertcount: '1',
        incidentcount: null
      };

      const incidentCounts =  {
        eventcount: null,
        alertcount: null,
        incidentcount: '1'
      };

      const mockDate = client.formatTimestamp('2024-09-10T18:21:46.000Z');
      const queryString = fs.readFileSync(path.resolve(__dirname, './insert-incident.sql'), 'utf8');
      await client.query(queryString, [mockDate, mockDate]);

      const res = await client.query('SELECT * FROM INCIDENT_DASHBOARD ORDER BY eventCount');
      Object.keys(alertCounts).forEach(c => expect(res.rows[0]).to.have.property(c, alertCounts[c]));
      Object.keys(incidentCounts).forEach(c => expect(res.rows[1]).to.have.property(c, incidentCounts[c]));
    });


    it('should update counts on updated incident', async () => {
      const alertCounts =  {
        eventcount: '400',
        alertcount: '1',
        incidentcount: null
      };

      const incidentCounts =  {
        eventcount: null,
        alertcount: null,
        incidentcount: '1'
      };

      await client.query(`UPDATE INCIDENTS_REPORTER_STATUS SET owner = 'Bob' WHERE id = 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5'`);

      const res = await client.query('SELECT * FROM INCIDENT_DASHBOARD ORDER BY eventCount');
      Object.keys(alertCounts).forEach(c => expect(res.rows[0]).to.have.property(c, alertCounts[c]));
      Object.keys(incidentCounts).forEach(c => expect(res.rows[1]).to.have.property(c, incidentCounts[c]));
    });
  });
});
