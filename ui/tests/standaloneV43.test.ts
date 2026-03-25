import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

describe('standalone v43 artifact', () => {
  const file = path.resolve(__dirname, '../agijobmanager_genesis_job_mainnet_2026-03-05-v43.html');
  const loadHtml = () => fs.readFileSync(file, 'utf8');

  it('exists and is versioned as v43', () => {
    expect(fs.existsSync(file)).toBe(true);
    expect(loadHtml()).toContain('Prime Mainnet Console · v43');
  });

  it('pins required identity contract and ABI reads/writes', () => {
    const html = loadHtml();
    expect(html).toContain('const FREE_TRIAL_REGISTRAR_IDENTITY = "0x7811993CbcCa3b8bb35a3d919F3BA59eeFbeAA9a";');
    [
      'ROOT_NAME','ROOT_NODE','TRIAL_PERIOD','PARENT_GRACE_PERIOD','MIN_LABEL_LENGTH','MAX_LABEL_LENGTH','REQUIRED_CHILD_FUSES',
      'owner','pendingOwner','paused','rootActive','wrapper','ensRegistry','name','symbol','rootHealth','preview','available',
      'validateLabel','nodeForLabel','fullNameForLabel','balanceOf','ownerOf','locked','labelData','tokenURI','register','claimIdentity','syncIdentity','syncIdentityByLabel'
    ].forEach((method) => expect(html).toContain(`"name":"${method}"`));
  });

  it('keeps direct identity routing on FreeTrialSubdomainRegistrarIdentity with 0 ETH', () => {
    const html = loadHtml();
    expect(html).toContain("freeTrialRegistrarIdentity.methods.register(local.label).send({from:userAccount, value:'0'})");
    expect(html).toContain("freeTrialRegistrarIdentity.methods.claimIdentity(local.label).send({from:userAccount, value:'0'})");
    expect(html).toContain("freeTrialRegistrarIdentity.methods.syncIdentityByLabel(local.label).send({from:userAccount, value:'0'})");
    expect(html).toContain("['Contract', 'FreeTrialSubdomainRegistrarIdentity']");
    expect(html).toContain("['Contract address', FREE_TRIAL_REGISTRAR_IDENTITY]");
    expect(html).toContain("['ETH value', '0']");
    expect(html).toContain("['Route', action==='register' ? 'Combined wrapped name + soulbound identity'");
    expect(html).toContain("['Name-only public route', 'Not exposed in this console']");
  });

  it('uses deterministic state machine + normalized snapshot + stale-request guards', () => {
    const html = loadHtml();
    expect(html).toContain("identity:{preview:null,rootHealth:null,label:\"\",tokenData:null,previewLabel:\"\",requestId:0,activeRequestId:0,state:'idle_no_label',snapshot:null");
    expect(html).toContain("const state = !local.label ? 'idle_no_label'");
    expect(html).toContain(": !local.ok ? 'invalid_label'");
    expect(html).toContain("? 'loading_reads'");
    expect(html).toContain("? 'preview_failed'");
    expect(html).toContain("'write_ready'");
    expect(html).toContain("'write_blocked'");
    expect(html).toContain("APP_STATE.identity.state = 'dossier_loading';");
    expect(html).toContain("APP_STATE.identity.state = 'dossier_loaded';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_review';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_pending';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_success';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_failed';");
    expect(html).toContain("const snapshot = {chainId:isMainnet?1:(APP_STATE.wallet?.chainId||null), wallet:userAccount||'', label:local.label, contract:FREE_TRIAL_REGISTRAR_IDENTITY");
    expect(html).toContain('if(!isCurrentIdentityRequest(requestId)) return;');
  });

  it('parses preview/rootHealth deterministically and maps status-to-recommendation', () => {
    const html = loadHtml();
    expect(html).toContain('function parseIdentityPreviewResult(v)');
    expect(html).toContain('if(fromArray && v.length < 22) return null;');
    expect(html).toContain('function parseIdentityRootHealthResult(health)');
    expect(html).toContain('function identityPreviewInconsistencies(p)');
    expect(html).toContain("0:'available',1:'active',2:'claimable',3:'expired',4:'desynced',5:'invalid-label',6:'root-inactive',7:'parent-unusable',8:'unavailable'");
    expect(html).toContain("if(status === 0) return {method:'register', reason:'Status AVAILABLE', fallback:false};");
    expect(html).toContain("if(status === 2) return {method:'claimIdentity', reason:'Status CLAIMABLE', fallback:false};");
    expect(html).toContain("if(status === 3) return {method:'syncIdentityByLabel', reason:'Status EXPIRED', fallback:false};");
    expect(html).toContain("if(status === 4) return {method:'syncIdentityByLabel', reason:'Status DESYNCED', fallback:false};");
    expect(html).toContain("if(status === 5) return {method:'none', reason:'Status INVALID_LABEL', fallback:false};");
    expect(html).toContain("if(status === 6) return {method:'none', reason:'Status ROOT_INACTIVE', fallback:false};");
    expect(html).toContain("if(status === 7) return {method:'none', reason:'Status PARENT_UNUSABLE', fallback:false};");
    expect(html).toContain("if(preview?.inconsistencies?.length) return setToast('preview(label) returned inconsistent status/booleans. Retry preview before write.', 'warn');");
  });

  it('keeps preview-failure posture conservative without expert register fallback', () => {
    const html = loadHtml();
    expect(html).toContain("reason:'preview(label) read failed'");
    expect(html).toContain("recommendation='No write recommended'");
    expect(html).toContain("title='preview(label) failed for this label.'");
    expect(html).toContain("body='Retry preview(label). rootHealth() remains visible, but write controls stay conservative until preview is available.';");
    expect(html).not.toContain('expert direct register fallback available');
    expect(html).not.toContain('register(label) fallback');
  });

  it('keeps register write-gating independent of agent/validator verification posture', () => {
    const html = loadHtml();
    const gateStart = html.indexOf('function identityWriteLockedReason(preview)');
    const gateEnd = html.indexOf('function deriveAlphaIdentityUiState()', gateStart);
    expect(gateStart).toBeGreaterThan(-1);
    expect(gateEnd).toBeGreaterThan(gateStart);
    const gateBody = html.slice(gateStart, gateEnd);
    expect(gateBody).toContain("if(!userAccount) return 'Connect wallet to continue.';");
    expect(gateBody).toContain("if(!isMainnet) return 'Switch to Ethereum mainnet.';");
    expect(gateBody).toContain("if(!hasAcceptedTerms) return 'Accept terms to unlock writes.';");
    expect(gateBody).not.toContain('verified.agent');
    expect(gateBody).not.toContain('verified.club');
    expect(gateBody).not.toContain('verified.agentAlpha');
    expect(gateBody).not.toContain('verified.clubAlpha');
  });

  it('renders not-applicable and graceful tokenURI parsing outcomes', () => {
    const html = loadHtml();
    expect(html).toContain("'Not applicable (identity not issued)'");
    expect(html).toContain("'Identity not yet issued'");
    expect(html).toContain('APP_STATE.identity.errors.tokenDossier = `tokenURI parse failed:');
    expect(html).toContain("if(el('alphaIdentityTokenMetaName')) el('alphaIdentityTokenMetaName').textContent = 'Malformed tokenURI metadata payload';");
  });

  it('keeps mobile action rail + sticky review affordance copy in place', () => {
    const html = loadHtml();
    expect(html).toContain('Mobile-ready action rail');
    expect(html).toContain('Final transaction review keeps the authorize control pinned within reach on mobile.');
    expect(html).toContain('Authorize only when this summary matches your intent and wallet.');
  });

  it('removes public compatibility-alias wording and legacy duplicate identity review modal', () => {
    const html = loadHtml();
    expect(html).not.toContain('Compatibility register alias');
    expect(html).not.toContain('Compatibility-only alias');
    expect(html).not.toContain('Legacy modal retained for backwards compatibility');
    expect(html).not.toContain('id="alphaMintReviewModal"');
    expect(html).toContain("if(el('mintAlphaAgentBtn')) el('mintAlphaAgentBtn').disabled = true;");
  });

  it('renders executive review memo sections with preview/root source and advanced disclosure', () => {
    const html = loadHtml();
    expect(html).toContain('Mainnet Authorization Memo');
    expect(html).toContain('Source: preview(label) + rootHealth()');
    expect(html).toContain('Decision summary');
    expect(html).toContain('Action facts');
    expect(html).toContain('Why this action is available now');
    expect(html).toContain('Advanced technical facts');
    expect(html).toContain('Authorize register(string)');
    expect(html).toContain("if(lockedReason) return setToast(lockedReason, 'warn');");
  });

  it('hardens admin argument modal wiring with null guards and contract-specific subtitle address', () => {
    const html = loadHtml();
    expect(html).toContain("if(!modal || !formNode || !confirmBtn || !cancelBtn || !closeBtn){");
    expect(html).toContain("setToast('Admin argument modal is unavailable in this build.', 'bad');");
    expect(html).toContain("resolvedEnsJobPagesAddress || ensJobPages?.options?.address || 'unresolved ENSJobPages address'");
    expect(html).toContain("AGI_JOB_MANAGER || agiJobManager?.options?.address || 'unresolved AGIJobManager address'");
    expect(html).toContain("modal.addEventListener('click', onBackdropClick);");
  });
});
