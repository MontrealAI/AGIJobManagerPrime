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
    expect(rootHealth?.outputs?.[0]?.type).toBe('tuple');
    expect(rootHealth?.outputs?.[0]?.internalType).toBe('struct FreeTrialSubdomainRegistrarIdentity.RootHealthView');
    expect(rootHealth?.outputs?.[0]?.components?.length).toBe(13);
    expect(labelData?.outputs?.[0]?.type).toBe('tuple');
    expect(labelData?.outputs?.[0]?.internalType).toBe('struct FreeTrialSubdomainRegistrarIdentity.LabelData');
  });

  it('decodes preview tuple-returning variants (array, wrapped tuple, indexed hybrid)', () => {
    const ctx = loadIdentityRuntimeFns();
    const parseIdentityPreviewResult = ctx.parseIdentityPreviewResult as (v: any) => any;

    const sampleArray = [
      true,'99999999.alpha.agent.agi.eth','99999999','0x' + '1'.repeat(64),'0x' + '2'.repeat(64),'123456789',
      true, false, true, true, true, true, true, false, true, false,
      '0x3333333333333333333333333333333333333333','0x4444444444444444444444444444444444444444','0x5555555555555555555555555555555555555555',
      '1710000000', '1715000000', 0,
    ];
    expect(parseIdentityPreviewResult(sampleArray).statusLabel).toBe('available');

    const wrappedTuple = { 0: { ...parseIdentityPreviewResult(sampleArray), status: 2, claimable: true, registrable: false } };
    expect(parseIdentityPreviewResult(wrappedTuple).statusLabel).toBe('claimable');

    const indexedOnly = {
      0: true, 1: 'gggggggg.alpha.agent.agi.eth', 2: 'gggggggg', 3: '0x' + '1'.repeat(64), 4: '0x' + '2'.repeat(64), 5: '987654321',
      6: true, 7: false, 8: true, 9: true, 10: true, 11: true, 12: true, 13: false, 14: true, 15: false,
      16: '0x3333333333333333333333333333333333333333', 17: '0x4444444444444444444444444444444444444444', 18: '0x5555555555555555555555555555555555555555',
      19: '1710000000', 20: '1715000000', 21: 0, validLabel: true,
    };
    const parsedIndexed = parseIdentityPreviewResult(indexedOnly);
    expect(parsedIndexed.registrable).toBe(true);
    expect(parsedIndexed.status).toBe(0);
  });

  it('decodes rootHealth tuple variants (direct object, indexed object, nested wrapper)', () => {
    const ctx = loadIdentityRuntimeFns();
    const parseIdentityRootHealthResult = ctx.parseIdentityRootHealthResult as (v: any) => any;
    expect(parseIdentityRootHealthResult({ rootName: 'alpha.agent.agi.eth', rootNode: '0x' + 'a'.repeat(64), active: true, pausedOut: false, wrapperAddress: '0x1111111111111111111111111111111111111111', ensRegistryAddress: '0x2222222222222222222222222222222222222222', contractOwner: '0x3333333333333333333333333333333333333333', wrappedParentOwner: '0x4444444444444444444444444444444444444444', parentWrapped: true, parentLocked: true, registrarAuthorised: true, effectiveParentExpiry: '1710000000', rootUsable: true }).rootUsable).toBe(true);
    const indexedOnly = { 0: 'alpha.agent.agi.eth', 1: '0x' + 'b'.repeat(64), 2: true, 3: false, 4: '0x1111111111111111111111111111111111111111', 5: '0x2222222222222222222222222222222222222222', 6: '0x3333333333333333333333333333333333333333', 7: '0x4444444444444444444444444444444444444444', 8: true, 9: true, 10: true, 11: '1710000000', 12: true };
    expect(parseIdentityRootHealthResult(indexedOnly).rootName).toBe('alpha.agent.agi.eth');
    expect(parseIdentityRootHealthResult({ 0: indexedOnly }).active).toBe(true);
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
    const previewAvailable = { status: 0, validLabel: true, availableOut: true, registrable: true, pausedOut: false, rootActiveOut: true, rootUsable: true, inconsistencies: [] };
    ctx.APP_STATE.identity.async.preview = 'failed';
    expect(deriveIdentityRecommendation(null, rootHealth, local).method).toBe('none');
    ctx.APP_STATE.identity.async.preview = 'ok';
    expect(deriveIdentityRecommendation(previewAvailable, rootHealth, local).method).toBe('register');
  });

  it('enforces root inactive and parent unusable gating ahead of preview optimism', () => {
    const ctx = loadIdentityRuntimeFns();
    const deriveIdentityRecommendation = ctx.deriveIdentityRecommendation as (p: any, h: any, l: any) => any;
    const local = { ok: true, label: '99999999' };
    expect(deriveIdentityRecommendation({ status: 0, registrable: true, availableOut: true, rootActiveOut: false }, { active: false, rootUsable: true }, local).reason).toContain('inactive');
    expect(deriveIdentityRecommendation({ status: 0, registrable: true, availableOut: true, rootUsable: false }, { active: true, rootUsable: false }, local).reason).toContain('not usable');
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

  it('keeps registrable unresolved copy conservative when preview is unavailable', () => {
    expect(html.includes('Unknown (preview required)')).toBe(true);
    expect(html.includes("derivedAvailable === null ? 'Loading preview(label)' : String(!!derivedAvailable)")).toBe(false);
  });
});
