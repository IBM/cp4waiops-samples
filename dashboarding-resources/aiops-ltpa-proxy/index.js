import tls from 'node:tls';
import fjwt from '@fastify/jwt';
import fHttpProxy from '@fastify/http-proxy';
import buildGetJwks from 'get-jwks';
import Fastify from 'fastify';
import loadConfig from './lib/config.js';
import getCerts from './lib/tls/getCerts.js';
import ltpa2 from './lib/ltpa2.js';

async function run() {
  let config;

  try {
    config = await loadConfig();
  } catch (e) {
    console.error('Failed to load configuration:\n', e);
    process.exit(1);
  }

  if (config?.tls?.trusted_certificates_path) {
    const trustPath = config.tls.trusted_certificates_path;
    const additionalCerts = getCerts(trustPath);

    if (typeof tls.setDefaultCACertificates === 'function') {
      tls.setDefaultCACertificates(additionalCerts);
      console.log(`Loaded ${additionalCerts.length} trusted certificates`);
    } else {
      console.warn('Custom CA injection is not supported by this Node.js runtime; using default trust store');
    }
  } else {
    console.log('No additional trusted certificates provided');
  }

  if (!config.proxy?.tls?.cert || !config.proxy?.tls?.key) {
    console.error(
      'SSL certificate or key file not found. ' +
      'Please provide a certificate key pair, or ' +
      'generate a self signed one with "node generate-cert.js".'
    );
    process.exit(1);
  }

  const ltpa2Manager = await ltpa2(
    config.target.authentication.ltpa_key_file_path,
    config.target.authentication.ltpa_password,
    config.target.authentication.ltpa_user_template,
    config.target.authentication.ltpa_expiry_ms
  );

  const getJwks = buildGetJwks({
    issuersWhitelist: [config.proxy.authentication.endpoints.issuer],
    jwksPath: config.proxy.authentication.endpoints.jwks_path
  });

  const server = Fastify({
    logger: config.logging,
    https: {
      key: config.proxy.tls.key,
      cert: config.proxy.tls.cert
    }
  });

  server.register(fjwt, {
    decode: { complete: true },
    secret: (request, token) => {
      const {
        header: { kid, alg }
      } = token;

      return getJwks.getPublicKey({
        kid,
        domain: config.proxy.authentication.endpoints.issuer,
        alg
      });
    }
  });

  server.addHook('onRequest', async (request, reply) => {
    try {
      const user = await request.jwtVerify();
      request.log.info('Verified user: %s', user.sub);
      request.log.debug('User claims: %j', user);
    } catch (err) {
      request.log.error('Failed to verify user request', err);
      reply.send(err);
    }
  });

  server.register(fHttpProxy, {
    upstream: config.target.url,
    preHandler: (request, reply, done) => {
      ltpa2Manager.addTokenToRequest(request);

      if (request.headers.referer) {
        request.headers.referer = request.headers.referer.replace(
          request.headers.host,
          new URL(config.target.url).host
        );
      }

      done();
    },
    replyOptions: {
      rewriteHeaders: (headers, request) => {
        if (headers.location) {
          headers.location = headers.location.replace(
            new URL(config.target.url).host,
            request.headers.host
          );
        }

        delete headers['www-authenticate'];
        return headers;
      }
    }
  });

  server.listen({
    port: config.proxy.port,
    host: '0.0.0.0',
    listenTextResolver: address => {
      return `Proxy server listening on address [${address}]\n` +
        `  Target: ${config.target.url}\n` +
        `  JWKS endpoint: ${config.proxy.authentication.endpoints.issuer}${config.proxy.authentication.endpoints.jwks_path}`;
    }
  });

  const healthServer = Fastify({
    logger: config.logging,
    https: {
      key: config.proxy.tls.key,
      cert: config.proxy.tls.cert
    }
  });

  healthServer.get('/health', async () => {
    return { status: 'ok' };
  });

  healthServer.listen({
    port: config.proxy.health_port,
    host: '0.0.0.0',
    listenTextResolver: address => {
      return `Health server listening on address [${address}]`;
    }
  });
}

run();

// Made with Bob
