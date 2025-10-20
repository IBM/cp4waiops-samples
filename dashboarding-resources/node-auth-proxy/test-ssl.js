const https = require('https');
const fs = require('fs');
const path = require('path');

// Load environment variables from .env file
require('dotenv').config();

const PORT = process.env.PORT || 3000;

// Test the HTTPS connection to the proxy server
console.log(`Testing HTTPS connection to localhost:${PORT}...`);

// Options for the HTTPS request
// Note: We're ignoring SSL certificate validation for this test
// since we're using self-signed certificates
const options = {
  hostname: 'localhost',
  port: PORT,
  path: '/health',
  method: 'GET',
  rejectUnauthorized: false // Ignore certificate validation for testing
};

// Make the HTTPS request
const req = https.request(options, (res) => {
  console.log(`HTTPS Status Code: ${res.statusCode}`);
  console.log(`HTTPS Headers: ${JSON.stringify(res.headers)}`);

  let data = '';

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    console.log('Response Body:', data);
    console.log('\nSSL Test Successful! The server is properly configured with HTTPS.');
  });
});

req.on('error', (e) => {
  console.error('Error testing HTTPS connection:');
  console.error(e);
  console.log('\nMake sure the server is running with SSL enabled.');
  console.log('Check that the SSL_ENABLED=true is set in your .env file.');
  console.log('Verify that the certificate files exist in the specified paths.');
});

req.end();

// Made with Bob
