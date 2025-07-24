/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2025
 *
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
const fs = require('fs');
const zipLib = require('zip-lib');
const cpx = require('cpx-fixed');
const webpack = require('webpack');
const webpackConfig = require('../webpack.config.js');

// Create version number for the zip file
const versionFile = 'ver.txt';

if (!fs.existsSync(versionFile)) {
  // if ver.txt file does not exists then create one with 0 as its content
  fs.writeFileSync(versionFile, '0');
}

const nextVersion = Number(fs.readFileSync('./ver.txt').toString() || 0) + 1;
const zipFilePath = `dist/aiops-custom-widgets-v${nextVersion}.zip`;

// Ensure dist directory exists
if (!fs.existsSync('dist')) {
  fs.mkdirSync('dist');
}

// Run webpack to bundle the JS files
console.log('Running webpack to bundle widgets...');

// Use webpack programmatically for better error handling
webpack(webpackConfig, (err, stats) => {
  if (err) {
    console.error('Webpack error:', err.stack || err);
    if (err.details) {
      console.error('Error details:', err.details);
    }
    process.exit(1);
  }

  const info = stats.toJson();

  if (stats.hasErrors()) {
    console.error('Webpack compilation errors:');
    info.errors.forEach(error => {
      console.error(error);
    });
    process.exit(1);
  }

  if (stats.hasWarnings()) {
    console.warn('Webpack compilation warnings:');
    info.warnings.forEach(warning => {
      console.warn(warning);
    });
  }

  console.log('Webpack bundling completed successfully.');

  // Copy non-JS files (CSS, SVG, PNG, JPG, JSON)
  console.log('Copying non-JS assets...');
  cpx.copySync('widgets/**/*.{css,svg,png,jpg,json}', 'dist/widgets');

  // Create the zip file
  console.log(`Creating zip file: ${zipFilePath}`);
  zipLib.archiveFolder('dist/widgets', zipFilePath).then(function() {
    console.log(`########## ${zipFilePath} has been saved ##########`);
    fs.writeFileSync('./ver.txt', `${nextVersion}`);
  }, function(err) {
    console.error('Error creating zip file:', err);
    process.exit(1);
  });
});

// Made with Bob
