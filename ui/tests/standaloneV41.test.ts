import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

describe('standalone v41 artifact', () => {
  const file = path.resolve(__dirname, '../agijobmanager_genesis_job_mainnet_2026-03-05-v41.html');

  it('exists and is versioned as v41', () => {
    expect(fs.existsSync(file)).toBe(true);
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('Prime Mainnet Console · v41');
  });

  it('pins the required live contract addresses in the standalone snapshot', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e');
    expect(html).toContain('0xd5EF1dde7Ac60488f697ff2A7967a52172A78F29');
    expect(html).toContain('0x703011EF1C6E4277587eFe150e6cd74cA18F0069');
    expect(html).toContain('0x7811993CbcCa3b8bb35a3d919F3BA59eeFbeAA9a');
  });

  it('preserves review-first identity route language and soulbound posture', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('register(label)');
    expect(html).toContain('claimIdentity(label)');
    expect(html).toContain('syncIdentityByLabel(label)');
    expect(html).toContain('soulbound identity');
  });

  it('uses v41 continuity metadata and exposes historical-score read provenance', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('agijobmanagerprime.v41.uiContinuity');
    expect(html).toContain('previewHistoricalScore');
    expect(html).toContain('Historical score preview');
    expect(html).not.toContain('Unavailable in ENSJobPages public ABI (v40)');
  });
});
