import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

describe('standalone v42 artifact', () => {
  const file = path.resolve(__dirname, '../agijobmanager_genesis_job_mainnet_2026-03-05-v42.html');

  it('exists and is versioned as v42', () => {
    expect(fs.existsSync(file)).toBe(true);
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('Prime Mainnet Console · v42');
  });

  it('pins the required live Prime contract addresses in the standalone snapshot', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e');
    expect(html).toContain('0xd5EF1dde7Ac60488f697ff2A7967a52172A78F29');
    expect(html).toContain('0x703011EF1C6E4277587eFe150e6cd74cA18F0069');
    expect(html).toContain('0x7811993CbcCa3b8bb35a3d919F3BA59eeFbeAA9a');
  });

  it('uses compatibility ENS wording to avoid overclaiming authority', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('Compatibility ENS URI (preview/effective)');
    expect(html).toContain('authority snapshot established');
  });

  it('uses preview decision-card wording and removes authoritative-preview copy', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('Live preview(label) decision card');
    expect(html).not.toContain('Authoritative identity preview');
  });

  it('contains identity snapshot + stale-request guards and preview fallback messaging', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('function buildIdentitySnapshot');
    expect(html).toContain('isCurrentIdentityRequest');
    expect(html).toContain('preview(label) read failed — direct register fallback available.');
  });
});
