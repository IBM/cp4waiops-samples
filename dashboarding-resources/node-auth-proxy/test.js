// Simple test script to verify the LTPA token creation works properly
require('dotenv').config();
const { ltpa2Factory } = require('oniyi-ltpa');

const { LTPA_PASSWORD, LTPA_KEYS_PATH } = process.env;

// Convert the callback-based ltpa2Factory to a Promise
function getLtpa2Tools() {
  return new Promise((resolve, reject) => {
    ltpa2Factory(LTPA_KEYS_PATH, LTPA_PASSWORD, (err, ltpa2Tools) => {
      if (err) {
        reject(err);
      } else {
        resolve(ltpa2Tools);
      }
    });
  });
}

// Create LTPA token using the Promise-based approach
async function createLtpa2Token(ltpaContent) {
  try {
    console.log('Trying to get ltpa2Tools...');
    const ltpa2Tools = await getLtpa2Tools();

    console.log('Creating token...');
    const ltpaToken = ltpa2Tools.makeToken(ltpaContent);

    console.log('Token created successfully!');
    return ltpaToken;
  } catch (error) {
    console.error('Error creating LTPA token:', error);
    throw error;
  }
}

// Test the token creation
async function runTest() {
  try {
    const expiryTime = Date.now() + 3600000; // 1 hour
    const ltpaContent = {
      body: {
        expire: expiryTime,
        u: 'user\\:customRealm/impactadmin'
      },
      expires: expiryTime
    };

    console.log('Starting LTPA token creation test...');
    const token = await createLtpa2Token(ltpaContent);
    console.log('LTPA Token:', token);
    console.log('Test completed successfully!');
  } catch (error) {
    console.error('Test failed:', error);
  }
}

// Run the test
runTest();
