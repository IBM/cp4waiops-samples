const fs = require('fs');
const tls = require('tls');

/**
 * Fetches certificate files from a specified directory
 * @param {string} certpath - Path to the directory containing certificates
 * @returns {Array<string>} Array of certificate contents
 */
const fetchCertsInPath = (certpath) => {
  let certs = [];

  if (certpath) {
    if (fs.existsSync(certpath)) {
      certs = fs.readdirSync(certpath, { withFileTypes: true })
        .filter(entry => entry.isFile())
        .map(file => fs.readFileSync(`${certpath}/${file.name}`, { encoding: 'utf8' }));
    } else {
      console.error(`Proxy cert path specified as "${certpath}" but path did not exist`);
    }
  }
  return certs;
};

/**
 * Recursively fetches certificate files from a directory and its subdirectories
 * @param {string} certpath - Path to the directory containing certificates
 * @returns {Array<string>} Array of certificate contents
 */
const fetchCertsRecursivelyFromPath = (certpath) => {
  const certs = [];

  if (!certpath) {
    return certs;
  }

  try {
    fetchCertsInPath(certpath).forEach(cert => certs.push(cert));
    fs.readdirSync(certpath, { withFileTypes: true })
      .filter(entry => entry.isDirectory())
      .map(dir => dir.name)
      .forEach(subdir => {
        /* Recursive Step */
        fetchCertsRecursivelyFromPath(`${certpath}/${subdir}`)
          .forEach(cert => certs.push(cert));
      });
  } catch (err) {
    console.error('Error fetching certificates:', err);
  }

  return certs;
};

/**
 * Fetches all certificates from a directory and combines them with Node.js root certificates
 * @param {string} certpath - Path to the directory containing certificates
 * @returns {Array<string>} Array of certificate contents including Node.js root certificates
 */
const fetchAllCerts = (certpath) => {
  let userCerts = [];

  userCerts = fetchCertsRecursivelyFromPath(certpath);

  if (tls.rootCertificates) {
    return [
      ...userCerts,
      ...tls.rootCertificates
    ];
  }

  return userCerts;
};

module.exports = (certpath) => fetchAllCerts(certpath);
module.exports.fetchCertsInPath = fetchCertsInPath;

// Made with Bob
