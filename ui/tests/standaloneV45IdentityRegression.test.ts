import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { describe, expect, it } from 'vitest';

const htmlFile = path.resolve(__dirname, '../agijobmanager_genesis_job_mainnet_2026-03-05-v45.html');
const html = fs.readFileSync(htmlFile, 'utf8');

function extractAbiJsonArray(name: string) {
  const start = html.indexOf(`const ${name} = [`);
  const end = html.indexOf('\n    ];', start);
  if (start < 0 || end < 0) throw new Error(`Unable to locate ABI array ${name}`);
  const json = html.slice(start + `const ${name} = `.length, end + 6).trim().replace(/;$/, '');
  return JSON.parse(json) as Array<Record<string, any>>;
}

function loadIdentityRuntimeFns() {
  const start = html.indexOf('function validateAlphaLabelLocal(raw){');
  const end = html.indexOf('async function refreshIdentityState()', start);
  if (start < 0 || end < 0) throw new Error('Unable to locate identity runtime function block');
  const source = html.slice(start, end);
  const context: Record<string, any> = {
    APP_STATE: { identity: { requestId: 0, activeRequestId: 0, async: { preview: 'idle' } } },
    userAccount: '0x1111111111111111111111111111111111111111',
    isMainnet: true,
    hasAcceptedTerms: true,
    console,
  };
  vm.createContext(context);
  vm.runInContext(source, context);
  return context;
}

describe('standalone v45 identity tuple/decode regressions', () => {
  it('keeps canonical tuple ABI shape for preview/rootHealth/labelData', () => {
    const identityAbi = extractAbiJsonArray('FreeTrialSubdomainRegistrarIdentityABI');
    const preview = identityAbi.find((x) => x.type === 'function' && x.name === 'preview');
    const rootHealth = identityAbi.find((x) => x.type === 'function' && x.name === 'rootHealth');
    const labelData = identityAbi.find((x) => x.type === 'function' && x.name === 'labelData');

    expect(preview?.outputs?.[0]?.type).toBe('tuple');
    expect(preview?.outputs?.[0]?.internalType).toBe('struct FreeTrialSubdomainRegistrarIdentity.PreviewView');
    expect(preview?.outputs?.[0]?.components?.length).toBe(22);
    expect(preview?.outputs?.[0]?.components?.map((c: any) => c.name)).toEqual([
      'validLabel','fullName','labelOut','labelhash','node','tokenId','rootActiveOut','pausedOut','parentWrapped','parentLocked','registrarAuthorised','rootUsable','availableOut','identityExists','registrable','claimable','tokenOwner','wrappedOwner','resolver','currentWrappedExpiry','expectedNewExpiry','status'
    ]);

    expect(rootHealth?.outputs?.[0]?.type).toBe('tuple');
    expect(rootHealth?.outputs?.[0]?.internalType).toBe('struct FreeTrialSubdomainRegistrarIdentity.RootHealthView');
    expect(rootHealth?.outputs?.[0]?.components?.length).toBe(13);

    expect(labelData?.outputs?.[0]?.type).toBe('tuple');
    expect(labelData?.outputs?.[0]?.internalType).toBe('struct FreeTrialSubdomainRegistrarIdentity.LabelData');
  });

  it('decodes tuple-returning preview for web3 array and tuple-wrapper object shapes', () => {
    const ctx = loadIdentityRuntimeFns();
    const parseIdentityPreviewResult = ctx.parseIdentityPreviewResult as (v: any) => any;

    const sampleArray = [
      true,
      '99999999.alpha.agent.agi.eth',
      '99999999',
      '0x' + '1'.repeat(64),
      '0x' + '2'.repeat(64),
      '123456789',
      true, false, true, true, true, true, true, false, true, false,
      '0x3333333333333333333333333333333333333333',
      '0x4444444444444444444444444444444444444444',
      '0x5555555555555555555555555555555555555555',
      '1710000000', '1715000000', 0,
    ];
    const parsedArray = parseIdentityPreviewResult(sampleArray);
    expect(parsedArray.status).toBe(0);
    expect(parsedArray.statusLabel).toBe('available');
    expect(parsedArray.registrable).toBe(true);

    const wrappedTuple = { 0: { ...parsedArray, status: 2, claimable: true, registrable: false, availableOut: false, identityExists: false } };
    const parsedWrapped = parseIdentityPreviewResult(wrappedTuple);
    expect(parsedWrapped.status).toBe(2);
    expect(parsedWrapped.statusLabel).toBe('claimable');
    expect(parsedWrapped.claimable).toBe(true);
  });

  it('guards degraded mode: rootHealth success cannot unlock writes when preview fails', () => {
    const ctx = loadIdentityRuntimeFns();
    const deriveIdentityRecommendation = ctx.deriveIdentityRecommendation as (p: any, h: any, l: any) => any;
    ctx.APP_STATE.identity.async.preview = 'failed';

    ['99999999', 'gggggggg', 'eliteagent03'].forEach((label) => {
      const rec = deriveIdentityRecommendation(null, { active: true, rootUsable: true, pausedOut: false }, { ok: true, label });
      expect(rec.method).toBe('none');
      expect(rec.reason).toBe('preview(label) read failed');
    });
  });

  it('maps AVAILABLE / CLAIMABLE / EXPIRED / DESYNCED to exact action recommendations', () => {
    const ctx = loadIdentityRuntimeFns();
    const deriveIdentityRecommendation = ctx.deriveIdentityRecommendation as (p: any, h: any, l: any) => any;

    const baseHealth = { active: true, rootUsable: true, pausedOut: false };
    const local = { ok: true, label: 'eliteagent03' };

    expect(deriveIdentityRecommendation({ status: 0, registrable: true, availableOut: true, inconsistencies: [] }, baseHealth, local).method).toBe('register');
    expect(deriveIdentityRecommendation({ status: 2, claimable: true, inconsistencies: [] }, baseHealth, local).method).toBe('claimIdentity');
    expect(deriveIdentityRecommendation({ status: 3, identityExists: true, inconsistencies: [] }, baseHealth, local).method).toBe('syncIdentityByLabel');
    expect(deriveIdentityRecommendation({ status: 4, identityExists: true, inconsistencies: [] }, baseHealth, local).method).toBe('syncIdentityByLabel');
  });

  it('requires successful preview for AVAILABLE-state register unlock (local validation alone is insufficient)', () => {
    const ctx = loadIdentityRuntimeFns();
    const deriveIdentityRecommendation = ctx.deriveIdentityRecommendation as (p: any, h: any, l: any) => any;
    const local = { ok: true, label: '99999999' };
    const rootHealth = { active: true, rootUsable: true, pausedOut: false };
    const previewAvailable = {
      status: 0,
      validLabel: true,
      availableOut: true,
      registrable: true,
      pausedOut: false,
      rootActiveOut: true,
      rootUsable: true,
      inconsistencies: [],
    };

    // Phase A (regression case): rootHealth/local validation succeed but preview failed => conservative lock.
    ctx.APP_STATE.identity.async.preview = 'failed';
    ctx.APP_STATE.identity.recommendation = deriveIdentityRecommendation(null, rootHealth, local);
    expect(ctx.APP_STATE.identity.recommendation.method).toBe('none');
    expect(ctx.APP_STATE.identity.recommendation.reason).toBe('preview(label) read failed');

    // Phase B: preview succeeds with AVAILABLE status => canonical register path unlocks.
    ctx.APP_STATE.identity.async.preview = 'ok';
    ctx.APP_STATE.identity.recommendation = deriveIdentityRecommendation(previewAvailable, rootHealth, local);
    expect(ctx.APP_STATE.identity.recommendation.method).toBe('register');
    expect(ctx.APP_STATE.identity.recommendation.reason).toBe('Status AVAILABLE');
  });

  it('enforces root inactive and parent unusable gating ahead of preview optimism', () => {
    const ctx = loadIdentityRuntimeFns();
    const deriveIdentityRecommendation = ctx.deriveIdentityRecommendation as (p: any, h: any, l: any) => any;
    const local = { ok: true, label: '99999999' };

    const rootInactive = deriveIdentityRecommendation({ status: 0, registrable: true, availableOut: true, rootActiveOut: false }, { active: false, rootUsable: true }, local);
    expect(rootInactive.method).toBe('none');
    expect(rootInactive.reason).toContain('inactive');

    const parentUnusable = deriveIdentityRecommendation({ status: 0, registrable: true, availableOut: true, rootUsable: false }, { active: true, rootUsable: false }, local);
    expect(parentUnusable.method).toBe('none');
    expect(parentUnusable.reason).toContain('not usable');
  });

  it('prevents stale async overwrite using request tokens', () => {
    const ctx = loadIdentityRuntimeFns();
    const nextIdentityRequestToken = ctx.nextIdentityRequestToken as () => number;
    const isCurrentIdentityRequest = ctx.isCurrentIdentityRequest as (id: number) => boolean;

    const requestA = nextIdentityRequestToken();
    const requestB = nextIdentityRequestToken();

    expect(requestA).toBeLessThan(requestB);
    expect(isCurrentIdentityRequest(requestA)).toBe(false);
    expect(isCurrentIdentityRequest(requestB)).toBe(true);
  });
});
