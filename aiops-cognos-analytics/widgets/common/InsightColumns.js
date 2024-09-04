/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024
 * 
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
const INSIGHT_TYPE = {
  causal: 'aiops.ibm.com/insight-type/relationship/causal',
  seasonal: 'aiops.ibm.com/insight-type/seasonal-occurrence',
  runbook: 'aiops.ibm.com/insight-type/runbook',
  probableCause: 'aiops.ibm.com/insight-type/probable-cause',
  topology: 'aiops.ibm.com/insight-type/topology/resource',
  chatops: 'aiops.ibm.com/insight-type/chatops/metadata',
  itsm: 'aiops.ibm.com/insight-type/itsm/metadata',
  similarIncident: 'aiops.ibm.com/insight-type/similar-incidents',
  proposedBy: 'aiops.ibm.com/insight-type/proposed-by',
  ladResolutions: 'aiops.ibm.com/insight-type/lad/resolutions',
  ladTemplates: 'aiops.ibm.com/insight-type/lad/templates',
  businessCriticality: 'aiops.ibm.com/insight-type/business/criticality',
  anomaly: 'aiops.ibm.com/insight-type/anomaly',
  causalUnion: 'aiops.ibm.com/insight-type/relationship/causal-union',
  suppression: 'aiops.ibm.com/insight-type/suppression',
  feedback: 'aiops.ibm.com/insight-type/feedback',
  goldenSignal: 'aiops.ibm.com/insight-type/golden-signal',
  logTemplate: 'aiops.ibm.com/insight-type/log-template',
  incidentControl: 'aiops.ibm.com/insight-type/incidentcontrol',
  impactedApplication: 'aiops.ibm.com/insight-type/topology/group',
  storyTopology: 'aiops.ibm.com/insight-type/topology/story'
};

const INSIGHT_SOURCE = {
  temporal: 'aiops.ibm.com/insight-source/relationship/causal/temporal',
  temporalPattern: 'aiops.ibm.com/insight-source/relationship/causal/temporal-pattern',
  scopeGroup: 'aiops.ibm.com/insight-source/relationship/causal/custom',
  subTopologyGroup: 'aiops.ibm.com/insight-source/relationship/causal/topological-group'
};

export const INSIGHT_PATH = {
  temporal: `@insights.type='${INSIGHT_TYPE.causal}' and insights.source='${INSIGHT_SOURCE.temporal}'`,
  temporalPattern: `@insights.type='${INSIGHT_TYPE.causal}' and insights.source='${INSIGHT_SOURCE.temporalPattern}'`,
  seasonal: `@insights.type='${INSIGHT_TYPE.seasonal}'`,
  runbook: `@insights.type='${INSIGHT_TYPE.runbook}'`,
  topology: `@insights.type='${INSIGHT_TYPE.topology}'`,
  probableCause: `@insights.type='${INSIGHT_TYPE.probableCause}'`,
  scopeGroup: `@insights.type='${INSIGHT_TYPE.causal}' and insights.source='${INSIGHT_SOURCE.scopeGroup}'`,
  subTopologyGroup: `@insights.type='${INSIGHT_TYPE.causal}' and insights.source='${INSIGHT_SOURCE.subTopologyGroup}'`,
  chatops: `@insights.type='${INSIGHT_TYPE.chatops}'`,
  itsm: `@insights.type='${INSIGHT_TYPE.itsm}'`,
  similarIncident: `@insights.type='${INSIGHT_TYPE.similarIncident}'`,
  proposedBy: `@insights.type='${INSIGHT_TYPE.proposedBy}'`,
  ladResolutions: `@insights.type='${INSIGHT_TYPE.ladResolutions}'`,
  ladTemplates: `@insights.type='${INSIGHT_TYPE.ladTemplates}'`,
  businessCriticality: `@insights.type='${INSIGHT_TYPE.businessCriticality}'`,
  anomaly: `@insights.type='${INSIGHT_TYPE.anomaly}'`,
  causalUnion: `@insights.type='${INSIGHT_TYPE.causalUnion}'`,
  feedback: `@insights.type='${INSIGHT_TYPE.feedback}'`,
  suppression: `@insights.type='${INSIGHT_TYPE.suppression}'`,
  goldenSignal: `@insights.type='${INSIGHT_TYPE.goldenSignal}'`,
  logTemplate: `@insights.type='${INSIGHT_TYPE.logTemplate}'`,
  incidentControl: `@insights.type='${INSIGHT_TYPE.incidentControl}'`,
  impactedApplication: `@insights.type='${INSIGHT_TYPE.impactedApplication}'`,
  storyTopology: `@insights.type='${INSIGHT_TYPE.storyTopology}'`
};
