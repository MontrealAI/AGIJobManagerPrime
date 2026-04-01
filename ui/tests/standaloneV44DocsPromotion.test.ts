import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

const repoRoot = path.resolve(__dirname, '..', '..');

function read(relativePath: string) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

describe('2026-04-01 standalone canon promotion docs', () => {
  it('keeps 2026-04-01 as canonical and v45 as historical in operator-facing docs', () => {
    const uiReadme = read('ui/README.md');
    const docsUiReadme = read('docs/ui/README.md');
    const standaloneDoc = read('docs/ui/STANDALONE_HTML_UIS.md');
    const genesisRunbook = read('docs/ui/GENESIS_JOB_MAINNET_HTML_UI.md');

    expect(uiReadme).toContain('agijobmanager_genesis_job_mainnet_2026-04-01.html');
    expect(uiReadme).toContain('including the prior canonical `v45`');

    expect(docsUiReadme).toContain('Standalone Genesis Mainnet HTML UI (`2026-04-01`)');
    expect(standaloneDoc).toContain('**Canonical standalone artifact for this repo runbook.**');
    expect(standaloneDoc).toContain('including prior canonical `v45`');
    expect(genesisRunbook).toContain('`2026-04-01` is the documented standalone artifact for this runbook.');
  });

  it('documents direct register(string) parity on FreeTrialSubdomainRegistrarIdentity', () => {
    const identityLayer = read('docs/ui/IDENTITY_LAYER.md');
    const contractInterface = read('docs/ui/CONTRACT_INTERFACE.md');
    const deploymentMainnet = read('docs/ui/DEPLOYMENT_MAINNET.md');
    const versions = read('docs/ui/VERSIONS.md');

    expect(identityLayer).toContain('FreeTrialSubdomainRegistrarIdentity');
    expect(identityLayer).toContain('0x7811993CbcCa3b8bb35a3d919F3BA59eeFbeAA9a');
    expect(identityLayer).toContain('register(string)');

    expect(contractInterface).toContain('Primary public method: `register(string)`');
    expect(contractInterface).toContain('Value semantics: `0 ETH` (gas-only call path)');
    expect(contractInterface).toContain('chainId = 1');

    expect(deploymentMainnet).toContain('agijobmanager_genesis_job_mainnet_2026-03-05-v45.html');
    expect(deploymentMainnet).toContain('agijobmanager_genesis_job_mainnet_2026-03-05-v44.html');
    expect(versions).toContain('Genesis Mainnet standalone HTML');
  });
});
