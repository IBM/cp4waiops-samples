/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024, 2025
 *
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
import { INSIGHT_PATH } from './InsightColumns';
import Handlebars from 'handlebars';
import datetimeHelpers from './datetime';

// Register all datetime helpers with Handlebars in a single function
function registerDatetimeHelpers() {
  Object.entries(datetimeHelpers).forEach(([name, func]) => {
    if (typeof func === 'function') {
      Handlebars.registerHelper(name, func);
    }
  });
}

// Register all helpers
registerDatetimeHelpers();

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
Object.keys(INSIGHT_PATH).forEach((key) => {
  // use insights.type for enrichment insights and insights.source for grouping insights
  API_FIELD_MAP[`\`${INSIGHT_PATH[key]}\``] = INSIGHT_PATH[key].indexOf('insight-source') !== -1 ? 'insights.source' : 'insights.type';
  INSIGHT_FIELDS.push(`\`${INSIGHT_PATH[key]}\``);
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
  return conditions?.map((c) => {
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
            return `${getField(c.field, isForAPI, (c.addFieldPrefix === false ? '' : fieldPrefix))} ${getOperator(c.operator, isForAPI)}`;
          }
          return `${getField(c.field, isForAPI, (c.addFieldPrefix === false ? '' : fieldPrefix, c.apiField))} ${getOperator(c.operator, isForAPI)} ''`;
        }
        const a = c.value.map(v => `${getField(c.field, isForAPI, (c.addFieldPrefix === false ? '' : fieldPrefix), c.apiField)} ${getOperator(c.operator, isForAPI)} ${getValue(v, isForAPI, c)}`);
        return a.length === 0 ? '' : `(${a.join(' or ')})`;
      }
      return `${getField(c.field, isForAPI, (c.addFieldPrefix === false ? '' : fieldPrefix), c.apiField)} ${getOperator(c.operator, isForAPI)} ${getValue(c.value, isForAPI, c)}`;
    }
    const proccessedConditionSet = processConditionSet(c.conditions, c.operator, fieldPrefix, isForAPI);
    if (proccessedConditionSet) return `(${proccessedConditionSet})`;
    return '';
  }).filter(Boolean).join(` ${operator} `);
}

export const conditionSetToAPIQuery = (conditionSets) => {
  const query = processConditionSet(conditionSets.conditions, conditionSets.operator, '', true);
  if (query && !query.startsWith('(') && !query.endsWith(')')) {
    return `(${query})`;
  }

  return query;
};

export const resolveQuery = (queryString) => {
  const placeholder = /(\{\{[^\{\}]*\}\})/g;
  const resolved = queryString?.replace(placeholder, (value) => {
    let val = Handlebars.compile(value)({});
    if (val.startsWith('"') && val.endsWith('"')) {
      val = val.substring(1, val.length - 1);
    }
    return val;
  });
  return resolved;
};
