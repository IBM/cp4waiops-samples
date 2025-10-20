const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Create certs directory if it doesn't exist
const certsDir = path.join(__dirname, 'certs');
if (!fs.existsSync(certsDir)) {
  fs.mkdirSync(certsDir);
}

console.log('Generating self-signed SSL certificate...');

try {
  // Generate a private key
  execSync('openssl genrsa -out certs/key.pem 2048', { stdio: 'inherit' });

  // Generate a CSR (Certificate Signing Request)
  execSync('openssl req -new -key certs/key.pem -out certs/csr.pem -subj "/CN=localhost/O=Node Auth Proxy/C=US"', { stdio: 'inherit' });

  // Generate a self-signed certificate valid for 365 days
  execSync('openssl x509 -req -days 365 -in certs/csr.pem -signkey certs/key.pem -out certs/cert.pem', { stdio: 'inherit' });

  // Remove the CSR as it's no longer needed
  fs.unlinkSync(path.join(certsDir, 'csr.pem'));

  console.log('SSL certificate generated successfully!');
  console.log(`Certificate location: ${path.join(certsDir, 'cert.pem')}`);
  console.log(`Private key location: ${path.join(certsDir, 'key.pem')}`);
} catch (error) {
  console.error('Error generating SSL certificate:', error);
  process.exit(1);
}
