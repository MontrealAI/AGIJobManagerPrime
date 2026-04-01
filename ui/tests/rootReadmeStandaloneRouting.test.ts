import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

const repoRoot = path.resolve(__dirname, '..', '..');

describe('root README standalone routing', () => {
  it('routes repo-pinned standalone references to 2026-04-01 and preserves v45 lineage note', () => {
    const readme = fs.readFileSync(path.join(repoRoot, 'README.md'), 'utf8');
    expect(readme).toContain('agijobmanager_genesis_job_mainnet_2026-04-01.html');
    expect(readme).toContain('historical canonical snapshot: `v45`');
    expect(readme).not.toContain('agijobmanager_genesis_job_mainnet_2026-03-05-v39.html');
  });
});
