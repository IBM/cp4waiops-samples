/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2025
 *
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
const path = require('path');
const fs = require('fs');
const glob = require('glob');

// Find all JS files in the widgets directory
const entryFiles = glob.sync('./widgets/**/!(vendor)/*.js').reduce((entries, file) => {
  // Create entry points for each JS file
  const entryName = file.replace('./widgets/', '').replace('.js', '');
  entries[entryName] = file;
  return entries;
}, {});

module.exports = {
  mode: 'production',
  entry: entryFiles,
  output: {
    path: path.resolve(__dirname, 'dist'),
    libraryTarget: 'amd' // Use AMD format as per the existing babel config
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: [
              ['@babel/preset-env', {
                modules: false,
                targets: {
                  browsers: ['last 2 versions', 'ie >= 11']
                }
              }]
            ],
            plugins: ['@babel/plugin-transform-modules-amd']
          }
        }
      }
    ]
  },
  resolve: {
    alias: {
      handlebars: path.resolve(__dirname, 'node_modules/handlebars/dist/handlebars.min.js'),
      // Add aliases for widget paths to resolve import issues
      'widgets': path.resolve(__dirname, 'widgets')
    },
    extensions: ['.js', '.json'],
    modules: [path.resolve(__dirname), 'node_modules'],
    // Try to resolve relative paths first
    preferRelative: true
  },
  externals: {
    // Add any external dependencies here if needed
  },
  performance: {
    hints: false
  }
};
