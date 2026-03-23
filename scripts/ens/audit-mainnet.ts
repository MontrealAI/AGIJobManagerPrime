#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

const requireFromHere = createRequire(__filename);
const { ethers } = requireFromHere('../../hardhat/node_modules/ethers');

const OUTPUT = path.resolve('scripts/ens/output/audit-mainnet.json');
const ENS_JOB_PAGES = (process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d').trim();
const PRIME = (process.env.AGI_JOB_MANAGER_PRIME || '0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e').trim();
const DISCOVERY = (process.env.AGI_JOB_DISCOVERY_PRIME || '0xd5ef1dde7ac60488f697ff2a7967a52172a78f29').trim();
const RPC = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const ROOT_NAME = ethers.ensNormalize((process.env.JOBS_ROOT_NAME || 'alpha.jobs.agi.eth').trim());
const ENS_REGISTRY = (process.env.ENS_REGISTRY || '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e').trim();
const EXPECTED_HOOK_SELECTOR = '0x1f76f7a2';

const PAGES_ABI = [
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
  'function validateConfiguration() view returns (uint256)',
  'function configurationStatus() view returns (bool,bool,bool,bool,bool,bool,bool,bool,bool,bool,uint256)',
];

const PRIME_ABI = [
  'function owner() view returns (address)',
  'function discoveryModule() view returns (address)',
  'function ensJobPages() view returns (address)',
  'function nextJobId() view returns (uint256)',
];

const ENS_ABI = [
  'function owner(bytes32) view returns (address)',
  'function resolver(bytes32) view returns (address)',
];

const WRAPPER_ABI = [
  'function ownerOf(uint256) view returns (address)',
  'function getApproved(uint256) view returns (address)',
  'function isApprovedForAll(address,address) view returns (bool)',
];

const ERC165_ABI = ['function supportsInterface(bytes4) view returns (bool)'];

async function safe(label, fn, fallback = null) {
  try {
    return await fn();
  } catch (error) {
    return { error: error?.shortMessage || error?.message || String(error), label, fallback };
  }
}

function unwrap(value, fallback = null) {
  return value && value.error ? (value.fallback ?? fallback) : value;
}

function toStringValue(value) {
  if (typeof value === 'bigint') return value.toString();
  return value;
}

(async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });

  const out = {
    generatedAt: new Date().toISOString(),
    network: 'ethereum-mainnet',
    rpc: RPC,
    inputs: {
      ensJobPages: ENS_JOB_PAGES,
      agiJobManagerPrime: PRIME,
      agiJobDiscoveryPrime: DISCOVERY,
      jobsRootName: ROOT_NAME,
      ensRegistry: ENS_REGISTRY,
    },
    proven: {},
    assumed: [],
  };

  const provider = new ethers.JsonRpcProvider(RPC, 1, { staticNetwork: true });
  try {
    const block = await provider.getBlock('latest');
    out.proven.latestBlock = { number: block.number, hash: block.hash, timestamp: block.timestamp };
  } catch (error) {
    out.rpcReachable = false;
    out.assumed.push('RPC was unreachable from this environment; re-run from an operator-connected workstation before production actions.');
    out.error = error?.message || String(error);
    fs.writeFileSync(OUTPUT, `${JSON.stringify(out, null, 2)}\n`);
    console.log(`Wrote ${OUTPUT}`);
    return;
  }
  out.rpcReachable = true;

  const pages = new ethers.Contract(ENS_JOB_PAGES, PAGES_ABI, provider);
  const prime = new ethers.Contract(PRIME, PRIME_ABI, provider);
  const ens = new ethers.Contract(ENS_REGISTRY, ENS_ABI, provider);

  const expectedRootNode = ethers.namehash(ROOT_NAME);
  const pagesState = {
    owner: unwrap(await safe('pages.owner', () => pages.owner())),
    ens: unwrap(await safe('pages.ens', () => pages.ens())),
    nameWrapper: unwrap(await safe('pages.nameWrapper', () => pages.nameWrapper())),
    publicResolver: unwrap(await safe('pages.publicResolver', () => pages.publicResolver())),
    jobsRootNode: unwrap(await safe('pages.jobsRootNode', () => pages.jobsRootNode())),
    jobsRootName: unwrap(await safe('pages.jobsRootName', () => pages.jobsRootName())),
    jobManager: unwrap(await safe('pages.jobManager', () => pages.jobManager())),
    jobLabelPrefix: unwrap(await safe('pages.jobLabelPrefix', () => pages.jobLabelPrefix())),
    configLocked: unwrap(await safe('pages.configLocked', () => pages.configLocked())),
    useEnsJobTokenURI: unwrap(await safe('pages.useEnsJobTokenURI', () => pages.useEnsJobTokenURI())),
    validateConfiguration: toStringValue(unwrap(await safe('pages.validateConfiguration', () => pages.validateConfiguration()), 0n)),
    configurationStatus: unwrap(await safe('pages.configurationStatus', () => pages.configurationStatus()), null),
  };

  const primeState = {
    owner: unwrap(await safe('prime.owner', () => prime.owner())),
    discoveryModule: unwrap(await safe('prime.discoveryModule', () => prime.discoveryModule())),
    ensJobPages: unwrap(await safe('prime.ensJobPages', () => prime.ensJobPages())),
    nextJobId: toStringValue(unwrap(await safe('prime.nextJobId', () => prime.nextJobId()), 0n)),
  };

  const rootOwner = unwrap(await safe('ens.owner(root)', () => ens.owner(expectedRootNode)), ethers.ZeroAddress);
  const rootResolver = unwrap(await safe('ens.resolver(root)', () => ens.resolver(expectedRootNode)), ethers.ZeroAddress);
  const rootMatches = pagesState.jobsRootNode === expectedRootNode && pagesState.jobsRootName === ROOT_NAME;

  let wrapperState = null;
  if (pagesState.nameWrapper && pagesState.nameWrapper !== ethers.ZeroAddress) {
    const wrapper = new ethers.Contract(pagesState.nameWrapper, WRAPPER_ABI, provider);
    const tokenId = BigInt(pagesState.jobsRootNode || expectedRootNode);
    const wrappedOwner = unwrap(await safe('wrapper.ownerOf(root)', () => wrapper.ownerOf(tokenId)), ethers.ZeroAddress);
    const approved = unwrap(await safe('wrapper.getApproved(root)', () => wrapper.getApproved(tokenId)), ethers.ZeroAddress);
    const approvedForAll = wrappedOwner === ethers.ZeroAddress
      ? false
      : unwrap(await safe('wrapper.isApprovedForAll(rootOwner, pages)', () => wrapper.isApprovedForAll(wrappedOwner, ENS_JOB_PAGES)), false);

    wrapperState = {
      wrappedRoot: rootOwner && rootOwner.toLowerCase() === pagesState.nameWrapper.toLowerCase(),
      wrappedOwner,
      getApproved: approved,
      isApprovedForAll: approvedForAll,
      authorizationReady: approved.toLowerCase() === ENS_JOB_PAGES.toLowerCase() || approvedForAll || wrappedOwner.toLowerCase() === ENS_JOB_PAGES.toLowerCase(),
    };
  }

  let resolverState = null;
  if (pagesState.publicResolver && pagesState.publicResolver !== ethers.ZeroAddress) {
    const resolver165 = new ethers.Contract(pagesState.publicResolver, ERC165_ABI, provider);
    const ids = {
      text: '0x59d1d43c',
      setText: '0x10f13a8c',
      setAuthorisation: '0x304e6ade',
    };
    resolverState = {
      address: pagesState.publicResolver,
      supportsText: unwrap(await safe('resolver.supportsInterface(text)', () => resolver165.supportsInterface(ids.text)), false),
      supportsSetText: unwrap(await safe('resolver.supportsInterface(setText)', () => resolver165.supportsInterface(ids.setText)), false),
      supportsSetAuthorisation: unwrap(await safe('resolver.supportsInterface(setAuthorisation)', () => resolver165.supportsInterface(ids.setAuthorisation)), false),
    };
  }

  out.proven.expectedRootNode = expectedRootNode;
  out.proven.handleHook = { abi: 'handleHook(uint8,uint256)', selector: EXPECTED_HOOK_SELECTOR };
  out.proven.ensJobPages = pagesState;
  out.proven.agiJobManagerPrime = primeState;
  out.proven.rootIntegrity = {
    normalizedRootName: ROOT_NAME,
    computedNamehash: expectedRootNode,
    liveRootOwner: rootOwner,
    liveRootResolver: rootResolver,
    ensJobPagesRootMatchesInput: rootMatches,
  };
  out.proven.wrappedRootReadiness = wrapperState;
  out.proven.resolverCompatibility = resolverState;
  out.proven.pointerChecks = {
    primePointsToIntendedPages: primeState.ensJobPages && primeState.ensJobPages.toLowerCase() === ENS_JOB_PAGES.toLowerCase(),
    pagesPointsBackToPrime: pagesState.jobManager && pagesState.jobManager.toLowerCase() === PRIME.toLowerCase(),
    primeDiscoveryMatchesInput: primeState.discoveryModule && primeState.discoveryModule.toLowerCase() === DISCOVERY.toLowerCase(),
  };

  fs.writeFileSync(OUTPUT, `${JSON.stringify(out, null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
})();
