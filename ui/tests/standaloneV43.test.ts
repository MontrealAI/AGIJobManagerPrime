import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

describe('standalone v43 artifact', () => {
  const file = path.resolve(__dirname, '../agijobmanager_genesis_job_mainnet_2026-03-05-v43.html');

  it('exists and is versioned as v43', () => {
    expect(fs.existsSync(file)).toBe(true);
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain('Prime Mainnet Console · v43');
  });

  it('keeps direct identity routing on FreeTrialSubdomainRegistrarIdentity', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain("freeTrialRegistrarIdentity.methods.register(local.label).send({from:userAccount, value:'0'})");
    expect(html).toContain("freeTrialRegistrarIdentity.methods.claimIdentity(local.label).send({from:userAccount, value:'0'})");
    expect(html).toContain("freeTrialRegistrarIdentity.methods.syncIdentityByLabel(local.label).send({from:userAccount, value:'0'})");
    expect(html).toContain("['Contract address', FREE_TRIAL_REGISTRAR_IDENTITY]");
    expect(html).toContain("['Route', action==='register' ? 'Combined wrapped name + soulbound identity'");
  });

  it('uses deterministic state/snapshot and conservative preview-failure posture', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).toContain("identity:{preview:null,rootHealth:null,label:\"\",tokenData:null,previewLabel:\"\",requestId:0,activeRequestId:0,state:'idle_no_label',snapshot:null");
    expect(html).toContain("const snapshot = {chainId:isMainnet?1:(APP_STATE.wallet?.chainId||null), wallet:userAccount||'', label:local.label, contract:FREE_TRIAL_REGISTRAR_IDENTITY");
    expect(html).toContain("reason:'preview(label) read failed'");
    expect(html).toContain('function identityPreviewInconsistencies(p)');
    expect(html).toContain('function parseIdentityRootHealthResult(health)');
    expect(html).toContain("APP_STATE.identity.state = local.ok ? 'loading_reads'");
    expect(html).toContain("APP_STATE.identity.state = local.ok ? (preview ? 'preview_loaded' : 'preview_failed')");
    expect(html).toContain("APP_STATE.identity.state = 'dossier_loading';");
    expect(html).toContain("APP_STATE.identity.state = 'dossier_loaded';");
    expect(html).toContain("if(preview?.inconsistencies?.length) return setToast('preview(label) returned inconsistent status/booleans. Retry preview before write.', 'warn');");
    expect(html).toContain("APP_STATE.identity.state = 'tx_review';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_pending';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_success';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_failed';");
    expect(html).not.toContain('expert direct register fallback available');
  });

  it('removes public compatibility-alias wording from identity flow', () => {
    const html = fs.readFileSync(file, 'utf8');
    expect(html).not.toContain('Compatibility register alias');
    expect(html).not.toContain('Compatibility-only alias');
  });

  it('keeps register write-gating independent of agent/validator verification posture', () => {
    const html = fs.readFileSync(file, 'utf8');
    const gateStart = html.indexOf('function identityWriteLockedReason(preview)');
    const gateEnd = html.indexOf('function deriveAlphaIdentityUiState()', gateStart);
    expect(gateStart).toBeGreaterThan(-1);
    expect(gateEnd).toBeGreaterThan(gateStart);
    const gateBody = html.slice(gateStart, gateEnd);
    expect(gateBody).toContain('if(!userAccount) return \'Connect wallet to continue.\';');
    expect(gateBody).toContain('if(!isMainnet) return \'Switch to Ethereum mainnet.\';');
    expect(gateBody).toContain('if(!hasAcceptedTerms) return \'Accept terms to unlock writes.\';');
    expect(gateBody).not.toContain('verified.agent');
    expect(gateBody).not.toContain('verified.club');
    expect(gateBody).not.toContain('verified.agentAlpha');
    expect(gateBody).not.toContain('verified.clubAlpha');
  });
});
