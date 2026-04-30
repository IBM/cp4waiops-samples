import { parse } from 'yaml';
import { readFile } from 'node:fs/promises';
import { readFileSync } from 'node:fs';

function buildParseOptions({ resolveFileReferences = true } = {}) {
  if (!resolveFileReferences) {
    return {};
  }

  return {
    customTags: [
      {
        identify: value => value instanceof FileReference,
        tag: '!file',
        resolve: (value, onError) => {
          try {
            return readFileSync(value, 'utf8');
          } catch (e) {
            onError(new Error(`Failed to read file ${value} referenced in configuration: ${e}`, {
              cause: e
            }));
          }
        }
      }
    ]
  };
}

export default async function loadConfig(options = {}) {
  let configText = await readFile('./etc/config/config.yaml', 'utf8');

  // Substitute environment variables (${VAR_NAME} syntax)
  configText = configText.replace(/\$\{([^}]+)\}/g, (match, varName) => {
    const value = process.env[varName];
    if (value === undefined) {
      console.warn(`Warning: Environment variable ${varName} is not set, using empty string`);
      return '';
    }
    return value;
  });

  const config = parse(configText, buildParseOptions(options));

  return config;
}

export async function loadRawConfig() {
  return loadConfig({ resolveFileReferences: false });
}

class FileReference {
  constructor(path) {
    this.path = path;
  }
}

// Made with Bob
