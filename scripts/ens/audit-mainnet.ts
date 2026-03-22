import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { ethers } = require('../../hardhat/node_modules/ethers');

const RPC = process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com';
const ENS_JOB_PAGES = process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d';
const MANAGER = process.env.AGI_JOB_MANAGER_PRIME || '0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e';
const DISCOVERY = process.env.AGI_JOB_DISCOVERY_PRIME || '0xd5ef1dde7ac60488f697ff2a7967a52172a78f29';
const ROOT = ethers.ensNormalize(process.env.JOBS_ROOT_NAME || 'alpha.jobs.agi.eth');
const ENS_REGISTRY = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';
const OUT = path.resolve('scripts/ens/output/audit-mainnet.json');

const ensJobPagesAbi = [
  'function owner() view returns (address)',
  'function ens() view returns (address)',
  'function nameWrapper() view returns (address)',
  'function publicResolver() view returns (address)',
  'function jobsRootNode() view returns (bytes32)',
  'function jobsRootName() view returns (string)',
  'function jobManager() view returns (address)',
  'function jobLabelPrefix() view returns (string)',
  'function configLocked() view returns (bool)',
  'function useEnsJobTokenURI() view returns (bool)',
  'function validateConfiguration() view returns (uint256)'
];

const managerAbi = [
  'function owner() view returns (address)',
  'function discoveryModule() view returns (address)',
  'function ensJobPages() view returns (address)'
];

const ensRegistryAbi = [
  'function owner(bytes32) view returns (address)',
  'function resolver(bytes32) view returns (address)'
];

async function safeCall(label: string, fn: () => Promise<any>) {
  try {
    return await fn();
  } catch (error: any) {
    return { error: error?.shortMessage || error?.message || String(error), label };
  }
}

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC, 1, { staticNetwork: true });
  const payload: any = {
    generatedAt: new Date().toISOString(),
    rpc: RPC,
    inputs: { ENS_JOB_PAGES, MANAGER, DISCOVERY, ROOT },
    rpcReachable: false,
    proven: {},
    assumptions: []
  };

  try {
    payload.proven.latestBlock = await provider.getBlockNumber();
    payload.rpcReachable = true;
  } catch (error: any) {
    payload.error = error?.message || String(error);
    payload.assumptions.push('Mainnet RPC was unreachable from the current execution environment.');
    fs.writeFileSync(OUT, JSON.stringify(payload, null, 2));
    return;
  }

  const pages = new ethers.Contract(ENS_JOB_PAGES, ensJobPagesAbi, provider);
  const manager = new ethers.Contract(MANAGER, managerAbi, provider);
  const ens = new ethers.Contract(ENS_REGISTRY, ensRegistryAbi, provider);
  const expectedRootNode = ethers.namehash(ROOT);

  payload.proven.expectedRootNode = expectedRootNode;
  payload.proven.ensJobPages = {
    owner: await safeCall('pages.owner', () => pages.owner()),
    ens: await safeCall('pages.ens', () => pages.ens()),
    nameWrapper: await safeCall('pages.nameWrapper', () => pages.nameWrapper()),
    publicResolver: await safeCall('pages.publicResolver', () => pages.publicResolver()),
    jobsRootNode: await safeCall('pages.jobsRootNode', () => pages.jobsRootNode()),
    jobsRootName: await safeCall('pages.jobsRootName', () => pages.jobsRootName()),
    jobManager: await safeCall('pages.jobManager', () => pages.jobManager()),
    jobLabelPrefix: await safeCall('pages.jobLabelPrefix', () => pages.jobLabelPrefix()),
    configLocked: await safeCall('pages.configLocked', () => pages.configLocked()),
    useEnsJobTokenURI: await safeCall('pages.useEnsJobTokenURI', () => pages.useEnsJobTokenURI()),
    validateConfiguration: String(await safeCall('pages.validateConfiguration', () => pages.validateConfiguration()))
  };

  payload.proven.manager = {
    owner: await safeCall('manager.owner', () => manager.owner()),
    discoveryModule: await safeCall('manager.discoveryModule', () => manager.discoveryModule()),
    ensJobPages: await safeCall('manager.ensJobPages', () => manager.ensJobPages())
  };

  payload.proven.discovery = {
    address: DISCOVERY
  };

  payload.proven.root = {
    configuredName: ROOT,
    expectedRootNode,
    liveOwner: await safeCall('ens.owner(root)', () => ens.owner(expectedRootNode)),
    liveResolver: await safeCall('ens.resolver(root)', () => ens.resolver(expectedRootNode))
  };

  fs.writeFileSync(OUT, JSON.stringify(payload, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
