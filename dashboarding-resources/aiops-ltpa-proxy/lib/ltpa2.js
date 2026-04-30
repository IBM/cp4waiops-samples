import { ltpa2Factory } from 'oniyi-ltpa';
import { promisify } from 'node:util';

const EXPIRY_GRACE_TIME = 60_000;

const createLtpa2 = promisify(ltpa2Factory);

export default async function ltpa2Manager(keysPath, keyPassword, userTemplate, expiryIntervalMs) {
  const ltpa2Manager = await createLtpa2(keysPath, keyPassword);

  const cachedKeys = new Map();

  return {
    addTokenToRequest(req) {
      let ltpaToken;

      if (cachedKeys.has(req.user.username)) {
        const cachedLtpaKey = cachedKeys.get(req.user.username);

        if (!(cachedLtpaKey.expiryTime < Date.now() - EXPIRY_GRACE_TIME)) {
          ltpaToken = cachedLtpaKey.key;
        } else {
          cachedKeys.delete(req.user.username);
        }
      } else {
        const expiryTime = Date.now() + expiryIntervalMs;
        const aiopsUser = req.user.username;

        const ltpaUser = userTemplate.replace('${aiopsUser}', aiopsUser);

        const ltpaContent = {
          body: {
            expire: expiryTime,
            u: ltpaUser
          },
          expires: expiryTime
        };

        ltpaToken = ltpa2Manager.makeToken(ltpaContent);

        cachedKeys.set(req.user.username, {
          key: ltpaToken,
          expiryTime
        });
      }

      const existingCookies = req.headers.cookie || '';
      const cookiesWithLtpa2 = existingCookies
        ? `${existingCookies}; LtpaToken2=${ltpaToken}`
        : `LtpaToken2=${ltpaToken}`;

      req.headers.cookie = cookiesWithLtpa2;

      delete req.headers.authorization;
    }
  };
}

// Made with Bob
