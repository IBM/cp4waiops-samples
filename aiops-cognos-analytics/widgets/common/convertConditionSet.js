define(["exports", "./InsightColumns"], function (_exports, _InsightColumns) {
  "use strict";

  Object.defineProperty(_exports, "__esModule", {
    value: true
  });
  _exports.conditionSetToAPIQuery = void 0;
  /* ******************************************************** {COPYRIGHT-TOP} ****
   * IBM Confidential
   * Licensed Materials - Property of IBM
   *
   * (C) Copyright IBM Corp. 2022, 2024 All Rights Reserved
   * 5725-Q09, 5737-M96
   *
   * US Government Users Restricted Rights - Use, duplication, or
   * disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
   ********************************************************* {COPYRIGHT-END} ****/

  // need to add mapping for more operators which are different
  // for MemDB and API
  const MEMDB_TO_API_OPERATOR_MAP = {
    contains: 'like',
    '!contains': 'not like',
    startsWith: 'like',
    endsWith: 'like',
    isEmpty: '=',
    '!isEmpty': '!='
  };

  // convert the insights fields to the format that API expects
  const API_FIELD_MAP = {};
  const INSIGHT_FIELDS = [];
  Object.keys(_InsightColumns.INSIGHT_PATH).forEach(key => {
    // use insights.type for enrichment insights and insights.source for grouping insights
    API_FIELD_MAP[`\`${_InsightColumns.INSIGHT_PATH[key]}\``] = _InsightColumns.INSIGHT_PATH[key].indexOf('insight-source') !== -1 ? 'insights.source' : 'insights.type';
    INSIGHT_FIELDS.push(`\`${_InsightColumns.INSIGHT_PATH[key]}\``);
  });
  function getField(field, isForAPI, prefix, apiField) {
    return apiField || API_FIELD_MAP[field] || field;
  }
  function getOperator(operator) {
    return MEMDB_TO_API_OPERATOR_MAP[operator] || operator;
  }
  function isBujiExpression(value) {
    const regex = /{{.+}}/;
    return regex.test(value);
  }
  function getValue(value, isForAPI, condition) {
    if (isForAPI) {
      if (condition.operator === 'startsWith') {
        return `'^${value}'`;
      }
      if (condition.operator === 'endsWith') {
        return `'${value}$'`;
      }
      if (condition.operator === 'isEmpty' || condition.operator === '!isEmpty') {
        return '';
      }
    }
    if (isBujiExpression(value)) {
      return value;
    }
    if (typeof value === 'string') {
      return `'${value}'`;
    }
    if (typeof value === 'boolean') {
      return !value ? 0 : 1;
    }
    return value;
  }
  function processConditionSet(conditions, operator, fieldPrefix = '', isForAPI) {
    return conditions?.map(c => {
      if (c.inactive) {
        return null;
      }
      if (c.type !== 'conditionSet') {
        if (Array.isArray(c.value)) {
          if (typeof c.value[0] === 'object') {
            const a = c.value.map(v => {
              const prefix = v.addFieldPrefix === false ? '' : fieldPrefix;
              if (v.additionalfields) {
                const fieldCondition = `${getField(v.field, isForAPI, prefix, v.apiField)} ${getOperator(v.operator, isForAPI)} ${getValue(v.value, isForAPI, c)}`;
                const additionalFieldsCondition = v.additionalfields.map(f => `${getField(f, isForAPI, prefix)} ${getOperator(v.operator, isForAPI)} ${getValue(v.value, isForAPI, v)}`);
                return `(${[fieldCondition, additionalFieldsCondition].join(`${v.operator === '=' ? ' and ' : ' or '}`)})`;
              }
              return `${getField(v.field, isForAPI, prefix, v.apiField)} ${getOperator(v.operator, isForAPI)} ${getValue(v.value, isForAPI, c)}`;
            });
            return a.length === 0 ? '' : `(${a.join(' or ')})`;
          }
          if (c.value.length === 0) {
            if (!isForAPI) {
              return `${getField(c.field, isForAPI, c.addFieldPrefix === false ? '' : fieldPrefix)} ${getOperator(c.operator, isForAPI)}`;
            }
            return `${getField(c.field, isForAPI, (c.addFieldPrefix === false ? '' : fieldPrefix, c.apiField))} ${getOperator(c.operator, isForAPI)} ''`;
          }
          const a = c.value.map(v => `${getField(c.field, isForAPI, c.addFieldPrefix === false ? '' : fieldPrefix, c.apiField)} ${getOperator(c.operator, isForAPI)} ${getValue(v, isForAPI, c)}`);
          return a.length === 0 ? '' : `(${a.join(' or ')})`;
        }
        return `${getField(c.field, isForAPI, c.addFieldPrefix === false ? '' : fieldPrefix, c.apiField)} ${getOperator(c.operator, isForAPI)} ${getValue(c.value, isForAPI, c)}`;
      }
      const proccessedConditionSet = processConditionSet(c.conditions, c.operator, fieldPrefix, isForAPI);
      if (proccessedConditionSet) return `(${proccessedConditionSet})`;
      return '';
    }).filter(Boolean).join(` ${operator} `);
  }
  const conditionSetToAPIQuery = conditionSets => {
    const query = processConditionSet(conditionSets.conditions, conditionSets.operator, '', true);
    if (query && !query.startsWith('(') && !query.endsWith(')')) {
      return `(${query})`;
    }
    return query;
  };
  _exports.conditionSetToAPIQuery = conditionSetToAPIQuery;
});
//# sourceMappingURL=convertConditionSet.js.map