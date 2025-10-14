require('dotenv').config();
const express = require('express');
const httpProxy = require('http-proxy');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const { ltpa2Factory } = require('oniyi-ltpa');
const url = require('url');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const TARGET_URL = process.env.TARGET_URL || 'https://api.example.com';
const JWKS_URI = process.env.JWKS_URI || 'https://your-auth-server.com/.well-known/jwks.json';
const JWKS_CACHE_TTL = parseInt(process.env.JWKS_CACHE_TTL || '3600000', 10);
const {
  LTPA_PASSWORD,
  LTPA_EXPIRY,
  LTPA_KEYS_PATH,
  LTPA_USER_TEMPLATE
} = process.env;

// Disable certificate validation for Node.js
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
console.warn('WARNING: SSL certificate validation is disabled. This should only be used in development environments.');

// Initialize JWKS client for JWT verification
const client = jwksClient({
  jwksUri: JWKS_URI,
  cache: true,
  cacheMaxAge: JWKS_CACHE_TTL, // Cache for 1 hour by default
  rateLimit: true,
  jwksRequestsPerMinute: 10
});

// Function to get the signing key
const getSigningKey = (header, callback) => {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) {
      return callback(err);
    }
    const signingKey = key.publicKey || key.rsaPublicKey;
    callback(null, signingKey);
  });
};

// Middleware to validate JWT token
const validateJwt = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authorization header missing or invalid' });
  }

  const token = authHeader.split(' ')[1];

  jwt.verify(token, getSigningKey, { algorithms: ['RS256'] }, (err, decoded) => {
    if (err) {
      console.error('JWT verification failed:', err);
      return res.status(401).json({ error: 'Invalid token' });
    }

    // Store user info from token for later use
    req.user = decoded;
    next();
  });
};

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
    const ltpa2Tools = await getLtpa2Tools();
    const ltpaToken = ltpa2Tools.makeToken(ltpaContent);

    return ltpaToken;
  } catch (error) {
    console.error('Error creating LTPA token:', error);
    throw error;
  }
}

async function decodeLtpa2Token(token) {
  try {
    const ltpa2Tools = await getLtpa2Tools();
    const decodedToken = ltpa2Tools.decode(token);

    return decodedToken;
  } catch (error) {
    console.error('Error decoding LTPA token:', error);
    throw error;
  }
}

// Create a proxy server instance
const proxy = httpProxy.createProxyServer({
  target: TARGET_URL,
  changeOrigin: true,
  secure: false // Disable certificate validation for proxy requests
});

// Handle proxy errors
proxy.on('error', (err, req, res) => {
  console.error('Proxy error:', err);
  res.writeHead(500, { 'Content-Type': 'text/plain' });
  res.end('Proxy error occurred');
});

// API route with JWT validation and LTPA token creation
app.use('/api', validateJwt, async (req, res) => {
  try {
    // Create LTPA token if configured
    if (LTPA_PASSWORD) {
      const expiryTime = Date.now() + parseInt(LTPA_EXPIRY || '3600000', 10);
      let impactUser = req.user.username;

      // Use the template from environment variable and substitute impactUser
      const userValue = LTPA_USER_TEMPLATE
        ? LTPA_USER_TEMPLATE.replace('${impactUser}', impactUser)
        : `user\\:customRealm/uid=${impactUser},ou=People,dc=ibm,dc=com`;

      const ltpaContent = {
        body: {
          expire: expiryTime,
          u: userValue
        },
        expires: expiryTime
      };

      // Await the token creation - this is the key improvement
      const ltpaToken = await createLtpa2Token(ltpaContent);

      // Get existing cookies if any
      const existingCookies = req.headers.cookie || '';

      // Combine with existing cookies if any
      const cookieValue = existingCookies
        ? `${existingCookies}; LtpaToken2=${ltpaToken}`
        : `LtpaToken2=${ltpaToken}`;

      // Set the cookie in the request headers
      req.headers.cookie = cookieValue;
      console.log('Added LtpaToken2 to outgoing request');
    }

    // Add user ID header
    req.headers['X-User-ID'] = req.user.sub || '';

    // Remove /api prefix from the path
    const targetPath = req.url.replace(/^\/api/, '');
    const targetUrl = url.parse(TARGET_URL);

    // Log the proxied request
    console.log(`Proxying request to: ${TARGET_URL}${targetPath}`);

    // Forward the request to the target server
    proxy.web(req, res, {
      target: `${targetUrl.protocol}//${targetUrl.host}`,
      path: targetPath
    });
  } catch (error) {
    console.error('Error in proxy middleware:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Start the server
app.listen(PORT, async () => {
  console.log(`Auth Proxy Server running on port ${PORT}`);
  console.log(`Proxying requests to ${TARGET_URL}`);
});
