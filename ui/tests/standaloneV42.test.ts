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

  it('uses decision-card wording for preview(label) instead of authoritative issuance wording', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('Live preview(label) decision card');
    expect(html).not.toContain('Authoritative identity preview');
  });

  it('contains deterministic preview status mapping and expert fallback messaging', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain("0:'available',1:'active',2:'claimable',3:'expired',4:'desynced',5:'invalid-label',6:'root-inactive',7:'parent-unusable',8:'unavailable'");
    expect(html).toContain('preview(label) failed; expert direct register fallback available');
    expect(html).toContain('const previewFresh = alphaIdentityPreviewIsFresh(local.label);');
  });

  it('renders direct register review facts against FreeTrialSubdomainRegistrarIdentity', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain("['Contract', 'FreeTrialSubdomainRegistrarIdentity']");
    expect(html).toContain("['Contract address', FREE_TRIAL_REGISTRAR_IDENTITY]");
    expect(html).toContain("['Method', methodLabel]");
    expect(html).toContain("['ETH value', '0']");
    expect(html).toContain("['Method selector', selector || 'Unavailable (contract not loaded)']");
    expect(html).toContain("freeTrialRegistrarIdentity.methods.register(local.label).send({from:userAccount, value:'0'})");
  });

  it('hydrates local identity derivations before preview(label) resolves', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain("freeTrialRegistrarIdentity.methods.fullNameForLabel(local.label).call()");
    expect(html).toContain("freeTrialRegistrarIdentity.methods.nodeForLabel(local.label).call()");
    expect(html).toContain("freeTrialRegistrarIdentity.methods.available(local.label).call()");
  });
});
