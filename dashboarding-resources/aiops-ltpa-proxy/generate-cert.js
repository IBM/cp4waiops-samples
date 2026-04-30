import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { loadRawConfig } from './lib/config.js';

const config = await loadRawConfig();

const certPath = config.proxy.tls.cert;
const keyPath = config.proxy.tls.key;

for (const filePath of [certPath, keyPath]) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

if (fs.existsSync(certPath) || fs.existsSync(keyPath)) {
  console.error('');
  console.error('[ERROR] Certificate or key file already exists. To regenerate delete these first or change the path in config.yaml.');
  console.error(`  Certificate path: ${certPath}`);
  console.error(`  Key path: ${keyPath}`);

  process.exit(1);
}

console.log('Generating self-signed SSL certificate...');

try {
  execSync(`openssl genrsa -out ${keyPath} 2048`, { stdio: 'inherit' });
  execSync(`openssl req -new -key ${keyPath} -out ${certPath}_csr.pem -subj "/CN=localhost/O=Node Auth Proxy/C=US"`, { stdio: 'inherit' });
  execSync(`openssl x509 -req -days 365 -in ${certPath}_csr.pem -signkey ${keyPath} -out ${certPath}`, { stdio: 'inherit' });

  console.error('');
  console.log('SSL certificate generated successfully!');
  console.log(`  Certificate location: ${certPath}`);
  console.log(`  Private key location: ${keyPath}`);
} catch (error) {
  console.error('Error generating SSL certificate:', error);
  process.exit(1);
}

// Made with Bob
