#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { ethers } = require('./lib/ethers');
const { CurlJsonRpcProvider } = require('./lib/json_rpc');

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


function serialize(value) {
  if (typeof value === 'bigint') return value.toString();
  if (Array.isArray(value)) return value.map((item) => serialize(item));
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serialize(item)]));
  }
  return value;
}

function methodState(value) {
  return value && value.error ? { available: false, error: value.error } : { available: true };
}



async function probeResolverWriteSurface(provider, resolver, payload) {
  if (!resolver || resolver === ethers.ZeroAddress) return false;
  try {
    provider.request('eth_call', [{ to: resolver, data: payload }, 'latest']);
    return true;
  } catch (error) {
    const message = error?.message || String(error);
    const match = message.match(/data=(0x[0-9a-fA-F]*)/);
    return Boolean(match && match[1] && match[1] !== '0x');
  }
}

async function probeResolverTextSurface(provider, resolver) {
  if (!resolver || resolver === ethers.ZeroAddress) return false;
  const TEXT_ABI = ['function text(bytes32,string) view returns (string)'];
  try {
    provider.readContract(resolver, TEXT_ABI, 'text', [ethers.ZeroHash, 'schema']);
    return true;
  } catch {
    return false;
  }
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

  const provider = new CurlJsonRpcProvider(RPC);
  try {
    const block = provider.getBlock('latest');
    out.proven.latestBlock = { number: block.number, hash: block.hash, timestamp: block.timestamp };
  } catch (error) {
    out.rpcReachable = false;
    out.assumed.push('RPC was unreachable from this environment; re-run from an operator-connected workstation before production actions.');
    out.error = error?.message || String(error);
    fs.writeFileSync(OUTPUT, `${JSON.stringify(serialize(out), null, 2)}\n`);
    console.log(`Wrote ${OUTPUT}`);
    return;
  }
  out.rpcReachable = true;

  const expectedRootNode = ethers.namehash(ROOT_NAME);
  const pagesState = {
    owner: unwrap(await safe('pages.owner', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'owner')[0])),
    ens: unwrap(await safe('pages.ens', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'ens')[0])),
    nameWrapper: unwrap(await safe('pages.nameWrapper', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'nameWrapper')[0])),
    publicResolver: unwrap(await safe('pages.publicResolver', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'publicResolver')[0])),
    jobsRootNode: unwrap(await safe('pages.jobsRootNode', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobsRootNode')[0])),
    jobsRootName: unwrap(await safe('pages.jobsRootName', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobsRootName')[0])),
    jobManager: unwrap(await safe('pages.jobManager', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobManager')[0])),
    jobLabelPrefix: unwrap(await safe('pages.jobLabelPrefix', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobLabelPrefix')[0])),
    configLocked: unwrap(await safe('pages.configLocked', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'configLocked')[0])),
    useEnsJobTokenURI: unwrap(await safe('pages.useEnsJobTokenURI', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'useEnsJobTokenURI')[0])),
    validateConfiguration: serialize(await safe('pages.validateConfiguration', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'validateConfiguration')[0])),
    configurationStatus: serialize(unwrap(await safe('pages.configurationStatus', () => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'configurationStatus'))), null)),
  };
  const pagesMethodAvailability = {
    validateConfiguration: methodState(await safe('pages.validateConfiguration', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'validateConfiguration')[0])),
    configurationStatus: methodState(await safe('pages.configurationStatus', () => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'configurationStatus')))),
  };

  const primeState = {
    owner: unwrap(await safe('prime.owner', () => provider.readContract(PRIME, PRIME_ABI, 'owner')[0])),
    discoveryModule: unwrap(await safe('prime.discoveryModule', () => provider.readContract(PRIME, PRIME_ABI, 'discoveryModule')[0])),
    ensJobPages: unwrap(await safe('prime.ensJobPages', () => provider.readContract(PRIME, PRIME_ABI, 'ensJobPages')[0])),
    nextJobId: toStringValue(unwrap(await safe('prime.nextJobId', () => provider.readContract(PRIME, PRIME_ABI, 'nextJobId')[0]), 0n)),
  };

  const rootOwner = unwrap(await safe('ens.owner(root)', () => provider.readContract(ENS_REGISTRY, ENS_ABI, 'owner', [expectedRootNode])[0]), ethers.ZeroAddress);
  const rootResolver = unwrap(await safe('ens.resolver(root)', () => provider.readContract(ENS_REGISTRY, ENS_ABI, 'resolver', [expectedRootNode])[0]), ethers.ZeroAddress);
  const rootMatches = pagesState.jobsRootNode === expectedRootNode && pagesState.jobsRootName === ROOT_NAME;

  let wrapperState = null;
  if (pagesState.nameWrapper && pagesState.nameWrapper !== ethers.ZeroAddress) {
    const tokenId = BigInt(pagesState.jobsRootNode || expectedRootNode);
    const wrappedOwner = unwrap(await safe('wrapper.ownerOf(root)', () => provider.readContract(pagesState.nameWrapper, WRAPPER_ABI, 'ownerOf', [tokenId])[0]), ethers.ZeroAddress);
    const approved = unwrap(await safe('wrapper.getApproved(root)', () => provider.readContract(pagesState.nameWrapper, WRAPPER_ABI, 'getApproved', [tokenId])[0]), ethers.ZeroAddress);
    const approvedForAll = wrappedOwner === ethers.ZeroAddress
      ? false
      : unwrap(await safe('wrapper.isApprovedForAll(rootOwner, pages)', () => provider.readContract(pagesState.nameWrapper, WRAPPER_ABI, 'isApprovedForAll', [wrappedOwner, ENS_JOB_PAGES])[0]), false);

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
    const ids = {
      text: '0x59d1d43c',
      setText: '0x10f13a8c',
      setAuthorisation: '0x304e6ade',
    };
    resolverState = {
      address: pagesState.publicResolver,
      supportsText: unwrap(await safe('resolver.supportsInterface(text)', () => provider.readContract(pagesState.publicResolver, ERC165_ABI, 'supportsInterface', [ids.text])[0]), false) || await probeResolverTextSurface(provider, pagesState.publicResolver),
      supportsSetText: unwrap(await safe('resolver.supportsInterface(setText)', () => provider.readContract(pagesState.publicResolver, ERC165_ABI, 'supportsInterface', [ids.setText])[0]), false) || await probeResolverWriteSurface(provider, pagesState.publicResolver, new ethers.Interface(['function setText(bytes32,string,string)']).encodeFunctionData('setText', [ethers.ZeroHash, 'schema', 'probe'])),
      supportsSetAuthorisation: unwrap(await safe('resolver.supportsInterface(setAuthorisation)', () => provider.readContract(pagesState.publicResolver, ERC165_ABI, 'supportsInterface', [ids.setAuthorisation])[0]), false) || await probeResolverWriteSurface(provider, pagesState.publicResolver, new ethers.Interface(['function setAuthorisation(bytes32,address,bool)']).encodeFunctionData('setAuthorisation', [ethers.ZeroHash, ethers.ZeroAddress, true])),
    };
  }

  out.proven.expectedRootNode = expectedRootNode;
  out.proven.handleHook = { abi: 'handleHook(uint8,uint256)', selector: EXPECTED_HOOK_SELECTOR };
  out.proven.ensJobPages = pagesState;
  out.proven.ensJobPagesMethodAvailability = pagesMethodAvailability;
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

  fs.writeFileSync(OUTPUT, `${JSON.stringify(serialize(out), null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
})();
