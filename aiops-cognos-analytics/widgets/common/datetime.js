/* ******************************************************** {COPYRIGHT-TOP} ****
* IBM Confidential
* Licensed Materials - Property of IBM
*
* (C) Copyright IBM Corp. 2025 All Rights Reserved
* 5725-Q09, 5737-M96
*
* US Government Users Restricted Rights - Use, duplication, or
* disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
********************************************************* {COPYRIGHT-END} ****/
'use strict';

const supportedTimeUnits = ['seconds', 'minutes', 'hours', 'days', 'months', 'years'];
module.exports = {
  second: (value) => {
    if (value === null || typeof value === 'undefined') {
      return null;
    }

    const time = parseTime(value);
    if (time === null) {
      return null;
    }

    return time.getUTCSeconds();
  },
  minute: (value) => {
    if (value === null || typeof value === 'undefined') {
      return null;
    }

    const time = parseTime(value);
    if (time === null) {
      return null;
    }

    return time.getUTCMinutes();
  },
  hour: (value) => {
    if (value === null || typeof value === 'undefined') {
      return null;
    }

    const time = parseTime(value);
    if (time === null) {
      return null;
    }

    return time.getUTCHours();
  },
  dayOfWeek: (value) => {
    if (value === null || typeof value === 'undefined') {
      return null;
    }

    const time = parseTime(value);
    if (time === null) {
      return null;
    }

    return time.getUTCDay();
  },
  dayOfMonth: (value) => {
    if (value === null || typeof value === 'undefined') {
      return null;
    }

    const time = parseTime(value);
    if (time === null) {
      return null;
    }

    return time.getUTCDate();
  },
  month: (value) => {
    if (value === null || typeof value === 'undefined') {
      return null;
    }

    const time = parseTime(value);
    if (time === null) {
      return null;
    }

    return time.getUTCMonth() + 1;
  },
  year: (value) => {
    if (value === null || typeof value === 'undefined') {
      return null;
    }

    const time = parseTime(value);
    if (time === null) {
      return null;
    }

    return time.getUTCFullYear();
  },
  currentTime: () => {
    return new Date().toISOString();
  },
  addTime: function(value, unit, date) {
    if (!supportedTimeUnits.includes(unit)) {
      return `Unsupported time unit ${unit}`;
    }
    const convertedValue = Number(value);
    if (!Number.isInteger(convertedValue)) {
      return 'Time value must be a number';
    }
    // handlebars passes a last argument as a hash object to all helpers, so if user does not pass date optionl param
    // it will be set to the hash object by handlebars, hence we need to check for the length of arguments
    return calculateTime('add', convertedValue, unit, arguments.length === 4 ? date : null);
  },
  subtractTime: function(value, unit, date) {
    if (!supportedTimeUnits.includes(unit)) {
      return `Unsupported time unit ${unit}`;
    }
    const convertedValue = Number(value);
    if (!Number.isInteger(convertedValue)) {
      return 'Time value must be a number';
    }
    // handlebars passes a last argument as a hash object to all helpers, so if user does not pass date optionl param
    // it will be set to the hash object by handlebars, hence we need to check for the length of arguments
    return calculateTime('subtract', convertedValue, unit, arguments.length === 4 ? date : null);
  }
};

function parseTime(value) {
  let date;
  try {
    date = new Date(value);
  } catch (err) {
    return null;
  }
  return date;
}

function calculateTime(operation, value, unit, dt) {
  const date = dt ? new Date(dt) : new Date();
  switch (unit) {
    case 'seconds':
      const seconds = date.getUTCSeconds();
      return new Date(date.setUTCSeconds(`${operation === 'add' ? seconds + value : seconds - value}`)).toISOString();
    case 'minutes':
      const minutes = date.getUTCMinutes();
      return new Date(date.setUTCMinutes(`${operation === 'add' ? minutes + value : minutes - value}`)).toISOString();
    case 'hours':
      const hours = date.getUTCHours();
      const updatedDate = new Date(date.setHours(`${operation === 'add' ? hours + value : hours - value}`));
      return new Date(updatedDate.getTime() - (updatedDate.getTimezoneOffset() * 60 * 1000)).toISOString();
    case 'days':
      const day = date.getUTCDate();
      return new Date(date.setUTCDate(`${operation === 'add' ? day + value : day - value}`)).toISOString();
    case 'months':
      const month = date.getUTCMonth();
      return new Date(date.setUTCMonth(`${operation === 'add' ? month + value : month - value}`)).toISOString();
    case 'years':
      const year = date.getUTCFullYear();
      return new Date(date.setUTCFullYear(`${operation === 'add' ? year + value : year - value}`)).toISOString();
    default:
      return date.toISOString();
  }
}
