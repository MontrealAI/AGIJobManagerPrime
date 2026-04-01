import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

describe('standalone 2026-04-01 premium canonical template regression', () => {
  const file = path.resolve(__dirname, '../agijobmanager_genesis_job_mainnet_2026-04-01.html');
  const html = () => fs.readFileSync(file, 'utf8');

  it('exists and carries 2026-04-01 version header', () => {
    expect(fs.existsSync(file)).toBe(true);
    expect(html()).toContain('Prime Mainnet Console · 2026-04-01');
    expect(html()).toContain('Mainnet Console 2026-04-01');
    expect(html()).toContain('agijobmanagerprime.v2026_04_01.procurementVault');
  });

  it('preserves local vault compatibility with legacy v45 key migration fallback', () => {
    const page = html();
    expect(page).toContain("const PRIME_LOCAL_VAULT_LEGACY_KEYS = ['agijobmanagerprime.v45.procurementVault'];");
    expect(page).toContain("const PRIME_LOCAL_VAULT_MIGRATION_MARK = 'agijobmanagerprime.v2026_04_01.procurementVault.migrated';");
    expect(page).toContain('localStorage.setItem(PRIME_LOCAL_VAULT_KEY, JSON.stringify(legacy));');
  });

  it('pins first-live-mainnet fixture values and derived budgets', () => {
    const page = html();
    expect(page).toContain('0xe90422f666b87e4962dd976015c18ee7a592dc40ddd6070b0f000a9404f93d1b');
    expect(page).toContain('100000 + 7020 = 107020 AGIALPHA');
    expect(page).toContain('604800 seconds (7 days)');
    expect(page).toContain('checkpoint:48');
    expect(page).toContain('selected:72');
    expect(page).toContain('finalists:3,minReveal:5,maxReveal:7');
    expect(page).toContain('historical:3500,trial:6500');
    expect(page).toContain('application:30, finalistStake:125, stipend:150, validatorReward:12, validatorBond:35');
  });

  it('renders non-fatal ENS hook messaging and minReputation inheritance semantics', () => {
    const page = html();
    expect(page).toContain('Success + non-fatal hook skip (NOT_CONFIGURED)');
    expect(page).toContain('minReputation = 0 inherits ManagerPrime premium threshold; it does not mean open access.');
  });

  it('keeps commitment helper formulas and local-packet warnings explicit', () => {
    const page = html();
    expect(page).toContain("return web3.utils.soliditySha3({type:'uint256',value:procurementId},{type:'address',value:agent},{type:'string',value:applicationURI},{type:'bytes32',value:salt}) || '';");
    expect(page).toContain("return web3.utils.soliditySha3({type:'uint256',value:procurementId},{type:'address',value:finalist},{type:'address',value:validator},{type:'uint8',value:scoreNum},{type:'bytes32',value:salt}) || '';");
    expect(page).toContain('Losing the salt makes reveal impossible.');
  });

  it('exposes first-live quick-copy actions for applicant and validator handoffs', () => {
    const page = html();
    expect(page).toContain('id="premiumCopyFirstLiveApplicantBtn"');
    expect(page).toContain('id="premiumCopyFirstLiveValidatorBtn"');
    expect(page).toContain('Applicant announcement copied.');
    expect(page).toContain('Validator briefing copied.');
  });

  it('ships an explicit 11-step create wizard rail with pass/warn/blocked language', () => {
    const page = html();
    expect(page).toContain('Create wizard rail (11-step operational checklist)');
    expect(page).toContain('id="premiumCreateWizardRail"');
    expect(page).toContain('Step 11 · Sign + success handoff');
    expect(page).toContain("const allowancesReady = (String(pel('premiumManagerApprovalState')?.textContent || '').trim() === 'Approved')");
    expect(page).toContain('Payout escrow allowance + discovery reserve allowance both sufficient');
  });

  it('promotes the first-live strip with explicit payout/discovery allowance targets and fixture URI', () => {
    const page = html();
    expect(page).toContain('verified production template');
    expect(page).toContain('Payout escrow allowance target');
    expect(page).toContain('Discovery reserve allowance target');
    expect(page).toContain('ipfs://bafkreihrscquk3h2zo6rsgtycp7lwxz2fqk24fmwcfkvvx3dapfmaxyyca');
  });

});
