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

  describe('Activity', () => {
    before(async () => {
      return await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_activity.sql'));
    });

    after(async () => {
      return await client.executeFile(path.resolve(__dirname, schemaPath + '/reporter_aiops_activity_remove.sql'));
    });

    it('should have the correct columns in ACTIVITY_ENTRY', async () => {
      const results = await client.query(`SELECT distinct(name) FROM sysibm.syscolumns WHERE tbname = 'ACTIVITY_ENTRY'`);
      const columnNames = results.rows.map((result) => result.name.toLowerCase());
      expect(columnNames).to.eql([
        'actioninstanceid',
        'comment',
        'createdtime',
        'id',
        'newvalue',
        'oldvalue',
        'parentid',
        'parenttype',
        'policyid',
        'runbookid',
        'runbookinstanceid',
        'runbookname',
        'runbookstatus',
        'runbooktype',
        'runbookversion',
        'tenantid',
        'timeadded',
        'type',
        'userid',
        'uuid'
      ]);
    });

    it('should have the correct columns in ACTIVITY_ENTRY_TYPES', async () => {
      const results = await client.query(`SELECT distinct(name) FROM sysibm.syscolumns WHERE tbname = 'ACTIVITY_ENTRY_TYPES'`);
      const columnNames = results.rows.map((result) => result.name.toLowerCase());
      expect(columnNames).to.eql([
        'description',
        'name',
        'type'
      ]);
    });

    it('should have all activity types populated', async () => {
      const results = await client.query(`SELECT type, name FROM ACTIVITY_ENTRY_TYPES ORDER BY type`);
      expect(results.rows.length).to.equal(11);
      
      const expectedTypes = [
        { type: 'alertadded', name: 'Alert Added' },
        { type: 'automation', name: 'Automation' },
        { type: 'comment', name: 'Comment' },
        { type: 'created', name: 'Created' },
        { type: 'eventadded', name: 'Event Added' },
        { type: 'notification', name: 'Notification' },
        { type: 'ownerchange', name: 'Owner Change' },
        { type: 'policy', name: 'Policy' },
        { type: 'statechange', name: 'State Change' },
        { type: 'unknown', name: 'Unknown' },
        { type: 'updated', name: 'Updated' }
      ];
      
      results.rows.forEach((row, index) => {
        expect(row.type).to.equal(expectedTypes[index].type);
        expect(row.name).to.equal(expectedTypes[index].name);
      });
    });

    it('should insert activity entry successfully', async () => {
      const expectedActivity = {
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'activity-001',
        parentid: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        parenttype: 'alert',
        createdtime: new Date('2024-09-10T23:21:46.000Z'),
        type: 'comment',
        userid: 'testuser@example.com',
        comment: 'This is a test comment on the alert',
        policyid: null,
        runbookid: null,
        runbookname: null,
        runbookversion: null,
        runbookinstanceid: null,
        runbookstatus: null,
        runbooktype: null,
        actioninstanceid: null,
        timeadded: new Date('2024-09-10T23:21:46.000Z'),
        oldvalue: null,
        newvalue: null,
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_activity-001'
      };

      const mockDate = client.formatTimestamp('2024-09-10T18:21:46.000Z');
      const queryString = fs.readFileSync(path.resolve(__dirname, './insert-activity.sql'), 'utf8');
      await client.query(queryString, [mockDate, mockDate]);

      const res = await client.query('SELECT * FROM ACTIVITY_ENTRY');
      expect(res.rows[0]).to.eql(expectedActivity);
    });

    it('should query activity by parent ID using index', async () => {
      const res = await client.query(`SELECT id, parentId, parentType FROM ACTIVITY_ENTRY WHERE parentId = 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5' ORDER BY createdTime DESC`);
      expect(res.rows.length).to.equal(1);
      expect(res.rows[0].id).to.equal('activity-001');
      expect(res.rows[0].parentid).to.equal('ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5');
      expect(res.rows[0].parenttype).to.equal('alert');
    });

    it('should query activity by user ID using index', async () => {
      const res = await client.query(`SELECT id, userId FROM ACTIVITY_ENTRY WHERE userId = 'testuser@example.com' ORDER BY createdTime DESC`);
      expect(res.rows.length).to.equal(1);
      expect(res.rows[0].id).to.equal('activity-001');
      expect(res.rows[0].userid).to.equal('testuser@example.com');
    });

    it('should query ACTIVITY_VW view correctly', async () => {
      const res = await client.query(`SELECT * FROM ACTIVITY_VW`);
      expect(res.rows.length).to.equal(1);
      
      const activity = res.rows[0];
      expect(activity.userid).to.equal('testuser@example.com');
      expect(activity.type).to.equal('Comment');
      expect(activity.comment).to.equal('This is a test comment on the alert');
      expect(activity.parentid).to.equal('ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5');
      expect(activity.parenttype).to.equal('alert');
    });

    it('should insert automation activity with runbook details', async () => {
      const automationActivity = {
        tenantid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255',
        id: 'activity-002',
        parentid: 'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5',
        parenttype: 'alert',
        createdtime: new Date('2024-09-10T23:21:46.000Z'),
        type: 'automation',
        userid: 'system',
        comment: 'Runbook executed successfully',
        policyid: null,
        runbookid: 'runbook-123',
        runbookname: 'Restart Service',
        runbookversion: 1,
        runbookinstanceid: 'instance-456',
        runbookstatus: 'completed',
        runbooktype: 'automated',
        actioninstanceid: 'action-789',
        timeadded: new Date('2024-09-10T23:21:46.000Z'),
        oldvalue: null,
        newvalue: null,
        uuid: 'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_activity-002'
      };

      const mockDate = client.formatTimestamp('2024-09-10T18:21:46.000Z');
      await client.query(`
        INSERT INTO ACTIVITY_ENTRY (
          tenantid, id, parentId, parentType, createdTime, type, userId, comment,
          runbookId, runbookName, runbookVersion, runbookInstanceId,
          runbookStatus, runbookType, actionInstanceId, timeAdded, uuid
        ) VALUES (
          'cfd95b7e-3bc7-4006-a4a8-a73a79c71255', 'activity-002',
          'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5', 'alert', '${mockDate}', 'automation',
          'system', 'Runbook executed successfully', 'runbook-123',
          'Restart Service', 1, 'instance-456', 'completed', 'automated',
          'action-789', '${mockDate}',
          'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_activity-002'
        )
      `);

      const res = await client.query(`SELECT * FROM ACTIVITY_ENTRY WHERE id = 'activity-002'`);
      expect(res.rows[0]).to.eql(automationActivity);
    });

    it('should insert state change activity with old and new values', async () => {
      const mockDate = client.formatTimestamp('2024-09-10T18:21:46.000Z');
      await client.query(`
        INSERT INTO ACTIVITY_ENTRY (
          tenantid, id, parentId, parentType, createdTime, type, userId, comment,
          oldValue, newValue, timeAdded, uuid
        ) VALUES (
          'cfd95b7e-3bc7-4006-a4a8-a73a79c71255', 'activity-003',
          'ea6cf743-7a3a-4d1a-8d6f-faaa1df573d5', 'alert', '${mockDate}', 'statechange',
          'admin@example.com', 'State changed from open to acknowledged',
          'open', 'acknowledged', '${mockDate}',
          'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_activity-003'
        )
      `);

      const res = await client.query(`SELECT * FROM ACTIVITY_ENTRY WHERE id = 'activity-003'`);
      expect(res.rows[0].type).to.equal('statechange');
      expect(res.rows[0].parenttype).to.equal('alert');
      expect(res.rows[0].oldvalue).to.equal('open');
      expect(res.rows[0].newvalue).to.equal('acknowledged');
    });

    it('should query activity by parentType using index', async () => {
      const res = await client.query(`SELECT id, parentType FROM ACTIVITY_ENTRY WHERE parentType = 'alert' ORDER BY createdTime DESC`);
      expect(res.rows.length).to.equal(3);
      res.rows.forEach(row => {
        expect(row.parenttype).to.equal('alert');
      });
    });

    it('should insert incident activity with parentType incident', async () => {
      const mockDate = client.formatTimestamp('2024-09-10T18:21:46.000Z');
      await client.query(`
        INSERT INTO ACTIVITY_ENTRY (
          tenantid, id, parentId, parentType, createdTime, type, userId, comment,
          timeAdded, uuid
        ) VALUES (
          'cfd95b7e-3bc7-4006-a4a8-a73a79c71255', 'activity-004',
          '24fba2e3-0000-4000-8000-000000000002', 'incident', '${mockDate}', 'comment',
          'testuser@example.com', 'This is a comment on the incident',
          '${mockDate}',
          'cfd95b7e-3bc7-4006-a4a8-a73a79c71255_activity-004'
        )
      `);

      const res = await client.query(`SELECT * FROM ACTIVITY_ENTRY WHERE id = 'activity-004'`);
      expect(res.rows[0].parenttype).to.equal('incident');
      expect(res.rows[0].parentid).to.equal('24fba2e3-0000-4000-8000-000000000002');
      expect(res.rows[0].comment).to.equal('This is a comment on the incident');
    });

    it('should filter activities by parentType', async () => {
      const alertActivities = await client.query(`SELECT id FROM ACTIVITY_ENTRY WHERE parentType = 'alert' ORDER BY id`);
      expect(alertActivities.rows.length).to.equal(3);
      expect(alertActivities.rows[0].id).to.equal('activity-001');
      expect(alertActivities.rows[1].id).to.equal('activity-002');
      expect(alertActivities.rows[2].id).to.equal('activity-003');

      const incidentActivities = await client.query(`SELECT id FROM ACTIVITY_ENTRY WHERE parentType = 'incident' ORDER BY id`);
      expect(incidentActivities.rows.length).to.equal(1);
      expect(incidentActivities.rows[0].id).to.equal('activity-004');
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
        'assignedcount',
        'criticalpct',
        'eventcount',
        'incidentcount',
        'inprogresscount',
        'onholdcount',
        'resolvedcount',
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
