import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

const repoRoot = path.resolve(__dirname, '..', '..');

describe('root README standalone routing', () => {
  it('routes repo-pinned standalone references to v45 and preserves v44 lineage note', () => {
    const readme = fs.readFileSync(path.join(repoRoot, 'README.md'), 'utf8');
    expect(readme).toContain('agijobmanager_genesis_job_mainnet_2026-03-05-v45.html');
    expect(readme).toContain('prior canonical snapshot: `v44`');
    expect(readme).not.toContain('agijobmanager_genesis_job_mainnet_2026-03-05-v39.html');
  });
});
