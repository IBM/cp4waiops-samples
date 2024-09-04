/* ******************************************************** {COPYRIGHT-TOP} ****
 * Copyright IBM Corp. 2024
 * 
 * This source code is licensed under the Apache-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 ********************************************************* {COPYRIGHT-END} ****/
const fs = require('fs');
const zipLib = require('zip-lib');

const versionFile = 'ver.txt';

if (!fs.existsSync(versionFile)) {
  // if ver.txt file does not exists then create one with 0 as its content
  fs.writeFileSync(versionFile, '0');
}

const nextVersion = Number(fs.readFileSync('./ver.txt').toString() || 0) + 1;
const zipFilePath = `dist/aiops-custom-widgets-v${nextVersion}.zip`;

zipLib.archiveFolder('dist/widgets', zipFilePath).then(function() {
  console.log(`########## ${zipFilePath} has been saved ##########`);
  fs.writeFileSync('./ver.txt', `${nextVersion}`);
}, function(err) {
  console.log(err);
});
