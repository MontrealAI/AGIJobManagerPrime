import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

describe('standalone v44 artifact', () => {
  const file = path.resolve(__dirname, '../agijobmanager_genesis_job_mainnet_2026-03-05-v44.html');
  const loadHtml = () => fs.readFileSync(file, 'utf8');

  it('exists and is versioned as v44', () => {
    expect(fs.existsSync(file)).toBe(true);
    expect(loadHtml()).toContain('Prime Mainnet Console · v44');
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
    expect(html).toContain("const contractShort = shortAddr(FREE_TRIAL_REGISTRAR_IDENTITY);");
    expect(html).toContain("<span class=\"k\">Value</span><span class=\"v\">0 ETH (gas only)</span>");
    expect(html).toContain("Wrapped label and soulbound identity are issued together in one public transaction.");
    expect(html).toContain("APP_STATE.identity.parity = {contract:FREE_TRIAL_REGISTRAR_IDENTITY");
  });

  it('uses deterministic state machine + normalized snapshot + stale-request guards', () => {
    const html = loadHtml();
    expect(html).toContain("identity:{preview:null,rootHealth:null,label:\"\",tokenData:null,previewLabel:\"\",requestId:0,activeRequestId:0,state:'idle_no_label',snapshot:null");
    expect(html).toContain("const state = !local.label ? 'idle_no_label'");
    expect(html).toContain(": !local.ok ? 'invalid_label'");
    expect(html).toContain("? 'loading_reads'");
    expect(html).toContain("? 'read_failed'");
    expect(html).toContain("'preview_inconsistent'");
    expect(html).toContain("'write_ready'");
    expect(html).toContain("'preview_ready'");
    expect(html).toContain("'write_blocked'");
    expect(html).toContain("APP_STATE.identity.state = 'review_open';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_pending';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_success';");
    expect(html).toContain("APP_STATE.identity.state = 'tx_failed';");
    expect(html).toContain("const snapshot = {chainId:isMainnet?1:(APP_STATE.wallet?.chainId||null), wallet:userAccount||'', label:local.label, contract:FREE_TRIAL_REGISTRAR_IDENTITY");
    expect(html).toContain("previewStatusLabel:preview?.statusLabel || 'unresolved'");
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
    expect(html).toContain('Authorize only when the action, label, wallet, and contract all match your intent.');
    expect(html).toContain('function trapAlphaIdentityReviewFocus(evt)');
    expect(html).toContain("const wasOpen = !!(m && m.classList.contains('open'));");
    expect(html).toContain('APP_STATE.identity.lastFocusedBeforeReview = null;');
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
    expect(html).toContain('Mainnet authorization memorandum');
    expect(html).toContain('Source: preview(label) + rootHealth()');
    expect(html).toContain('Decision summary');
    expect(html).toContain('Action facts');
    expect(html).toContain('Why this action is available now');
    expect(html).toContain('Advanced technical facts');
    expect(html).toContain('Advanced token facts');
    expect(html).toContain('Operational readiness');
    expect(html).toContain('Read inconsistency — refresh required before write.');
    expect(html).toContain('Ready · call:');
    expect(html).toContain('Authorize register(string)');
    expect(html).toContain("if(lockedReason) return setToast(lockedReason, 'warn');");
    expect(html).not.toContain('Token / node posture');
  });

  it('adds identity preflight simulation checks before review/submit', () => {
    const html = loadHtml();
    expect(html).toContain('async function runIdentityPreflight(action, label)');
    expect(html).toContain('await web3.eth.call(tx, \'latest\');');
    expect(html).toContain('estimateGas = await web3.eth.estimateGas(tx);');
    expect(html).toContain('if(!preflight.ok){');
    expect(html).toContain('Preflight blocked:');
  });

  it('decodes registrar custom errors into actionable messages', () => {
    const html = loadHtml();
    expect(html).toContain('const IDENTITY_CUSTOM_ERROR_SIGNATURES = {');
    expect(html).toContain('RootInactive');
    expect(html).toContain('InvalidLabel');
    expect(html).toContain('NameUnavailable(bytes32)');
    expect(html).toContain('function decodeIdentityCustomError(error)');
    expect(html).toContain('if(decoded) setToast(`${decoded.name}: ${decoded.remediation}`, \'warn\');');
  });

  it('keeps mobile-safe sticky review footer and removes legacy hidden-control copy', () => {
    const html = loadHtml();
    expect(html).toContain('#alphaIdentityReviewModal .alphaReviewFooter{position:sticky;bottom:0;z-index:6;');
    expect(html).toContain('#alphaIdentityReviewModal .alphaReviewBody{padding-bottom:calc(192px + env(safe-area-inset-bottom))}');
    expect(html).toContain('#alphaIdentityReviewModal .reviewFooter{margin-left:0;margin-right:0;');
    expect(html).toContain('Reserved hidden control');
    expect(html).not.toContain('Legacy hidden control');
  });


  it('covers full registrar custom error decode set and explicit zero-eth posture', () => {
    const html = loadHtml();
    [
      'RootInactive','InvalidLabel','ParentNotWrapped','ParentNotLocked','RegistrarNotAuthorised','ParentExpired',
      'NameUnavailable(bytes32)','WrappedOwnerMismatch(address,address)','WrappedFuseMismatch(uint32,uint32)',
      'WrappedExpiryMismatch(uint64,uint64)','IdentityNotEligible(uint256)','NonexistentToken(uint256)',
      'ZeroAddress()','DependencyHasNoCode(address)','EtherNotAccepted()','Soulbound()'
    ].forEach((signature) => expect(html).toContain(signature));
    expect(html).toContain("value:'0x0'");
  });

  it('keeps identity review modal semantically declared for accessibility', () => {
    const html = loadHtml();
    expect(html).toContain('id="alphaIdentityReviewModal" class="modalBackdrop" aria-hidden="true" role="dialog" aria-modal="true" aria-labelledby="alphaIdentityReviewTitle" aria-describedby="alphaIdentityReviewHelper"');
    expect(html).toContain('trapAlphaIdentityReviewFocus(e);');
  });

  it('blocks identity preflight when not on chainId 1', () => {
    const html = loadHtml();
    expect(html).toContain("if(!isMainnet) return {ok:false, verdict:'Blocked', note:'Switch to Ethereum mainnet before preflight.'");
  });

  it('hardens admin argument modal wiring with null guards and contract-specific subtitle address', () => {
    const html = loadHtml();
    expect(html).toContain("if(!modal || !formNode || !confirmBtn || !cancelBtn || !closeBtn){");
    expect(html).toContain("setToast('Admin argument modal is unavailable in this build.', 'bad');");
    expect(html).toContain("resolvedEnsJobPagesAddress || ensJobPages?.options?.address || 'unresolved ENSJobPages address'");
    expect(html).toContain("AGI_JOB_MANAGER || agiJobManager?.options?.address || 'unresolved AGIJobManager address'");
    expect(html).toContain("modal.addEventListener('click', onBackdropClick);");
  });

  it('adds discovery write preflight and stale-load guards for procurement inspector', () => {
    const html = loadHtml();
    expect(html).toContain('async function runDiscoveryWritePreflight({method, txBuilder})');
    expect(html).toContain("Switch to Ethereum mainnet before submitting discovery writes.");
    expect(html).toContain("Accept terms to unlock write authorization.");
    expect(html).toContain("await web3.eth.call(callTx, 'latest');");
    expect(html).toContain("let premiumProcurementLoadRequestId = 0;");
    expect(html).toContain("if(requestId !== premiumProcurementLoadRequestId) return;");
    expect(html).toContain("Awaiting live nextActionForProcurement()");
    expect(html).toContain("Target contract', value:`AGIJobDiscoveryPrime · ${AGI_JOB_DISCOVERY}`");
  });

  it('decodes discovery/manager custom errors for discovery preflight guidance', () => {
    const html = loadHtml();
    expect(html).toContain('const DISCOVERY_CUSTOM_ERROR_SIGNATURES = {');
    expect(html).toContain('const MANAGER_CUSTOM_ERROR_SIGNATURES = {');
    expect(html).toContain('function decodeDiscoveryCustomError(error)');
    expect(html).toContain('function decodeManagerCustomError(error)');
    expect(html).toContain('decodeDiscoveryCustomError(error) || decodeManagerCustomError(error) || decodeIdentityCustomError(error)');
    ['NoAdvanceableAction()','SettlementPaused()','DisputeAlreadyOpen()'].forEach((signature) => expect(html).toContain(signature));
  });

  it('hardens ENS preview reads with stale-request guards and authoritative vs projected copy', () => {
    const html = loadHtml();
    expect(html).toContain('let ensPreviewLoadRequestId = 0;');
    expect(html).toContain('const requestId = ++ensPreviewLoadRequestId;');
    expect(html).toContain('if(requestId !== ensPreviewLoadRequestId) return;');
    expect(html).toContain("TEXT_AWAITING_LIVE_READ = 'Awaiting live read'");
    expect(html).toContain("TEXT_PREVIEW_ONLY = 'Preview projection only'");
    expect(html).toContain('Authority snapshot established on-chain; effective label is available.');
    expect(html).toContain('Compatibility getter + resolver projection only until authority snapshot is established.');
  });
});
