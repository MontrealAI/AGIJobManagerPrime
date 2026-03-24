const { ethers } = require('hardhat');

const MANAGER_MODE_NONE = 'none';
const MANAGER_MODE_LEAN = 'lean-handleHook-compatible';
const MANAGER_MODE_RICH = 'rich-v1-view-compatible';

const ENS_JOB_PAGES_ABI = [
  'function jobManager() view returns (address)',
  'function validateConfiguration() view returns (uint256)',
  'function handleHook(uint8 hook, uint256 jobId)',
  'function onJobCreated(uint256 jobId, address employer, string specURI)',
  'function onJobAssigned(uint256 jobId, address employer, address assignedAgent)',
  'function onJobCompletionRequested(uint256 jobId, string completionURI)',
  'function onJobRevoked(uint256 jobId, address employer, address assignedAgent)',
  'function onJobLocked(uint256 jobId, address employer, address assignedAgent, bool burnFuses)',
];

async function hasCode(address) {
  if (!ethers.isAddress(address)) return false;
  const code = await ethers.provider.getCode(address);
  return !!code && code !== '0x';
}


function extractRevertData(error) {
  const candidates = [
    error?.data,
    error?.error?.data,
    error?.info?.error?.data,
    error?.revert?.data,
    error?.receipt?.revertReason,
  ];
  for (const candidate of candidates) {
    if (typeof candidate === 'string' && candidate.startsWith('0x') && candidate.length > 2) {
      return candidate;
    }
  }
  return '0x';
}

async function callSupports(target, fragment, args = [], from, options = {}) {
  if (!(await hasCode(target))) return false;
  const iface = new ethers.Interface([`function ${fragment}`]);
  try {
    const tx = { to: target, data: iface.encodeFunctionData(fragment.split('(')[0], args) };
    if (from) tx.from = from;
    await ethers.provider.call(tx);
    return true;
  } catch (error) {
    const revertData = extractRevertData(error);
    // By default, preflight requires a successful call (non-reverting path).
    // Optional read-surface probing may allow encoded revert payload as evidence
    // that a selector exists for this target.
    if (options.allowRevertDataAsSupported === true) {
      return revertData !== '0x';
    }
    return false;
  }
}

async function detectManagerCompatibility(manager, probeJobId = 0) {
  if (!(await hasCode(manager))) {
    return {
      managerMode: MANAGER_MODE_NONE,
      managerViewCompatible: false,
      metadataAutoWriteSupported: false,
      keeperRequired: true,
      reason: 'manager_missing_code',
    };
  }

  try {
    const iface = new ethers.Interface(['function ensJobManagerViewInterfaceVersion() view returns (uint256)']);
    const raw = await ethers.provider.call({ to: manager, data: iface.encodeFunctionData('ensJobManagerViewInterfaceVersion', []) });
    if (raw && raw !== '0x') {
      const [version] = iface.decodeFunctionResult('ensJobManagerViewInterfaceVersion', raw);
      if (version === 1n) {
        return {
          managerMode: MANAGER_MODE_RICH,
          managerViewCompatible: true,
          metadataAutoWriteSupported: true,
          keeperRequired: false,
          reason: 'ensJobManagerViewInterfaceVersion==1',
        };
      }
    }
  } catch (_) {}

  const richChecks = await Promise.all([
    callSupports(manager, 'getJobCore(uint256) view returns (address,address,uint256,uint256,uint256,bool,bool,bool,uint8)', [probeJobId], undefined, { allowRevertDataAsSupported: true }),
    callSupports(manager, 'getJobSpecURI(uint256) view returns (string)', [probeJobId], undefined, { allowRevertDataAsSupported: true }),
    callSupports(manager, 'getJobCompletionURI(uint256) view returns (string)', [probeJobId], undefined, { allowRevertDataAsSupported: true }),
  ]);
  if (richChecks.every(Boolean)) {
    return {
      managerMode: MANAGER_MODE_RICH,
      managerViewCompatible: true,
      metadataAutoWriteSupported: true,
      keeperRequired: false,
      reason: 'rich_view_surfaces_readable',
    };
  }

  const leanChecks = await Promise.all([
    callSupports(manager, 'jobEmployerOf(uint256) view returns (address)', [probeJobId], undefined, { allowRevertDataAsSupported: true }),
    callSupports(manager, 'jobAssignedAgentOf(uint256) view returns (address)', [probeJobId], undefined, { allowRevertDataAsSupported: true }),
  ]);
  if (leanChecks.every(Boolean)) {
    return {
      managerMode: MANAGER_MODE_LEAN,
      managerViewCompatible: false,
      metadataAutoWriteSupported: false,
      keeperRequired: true,
      reason: 'legacy_handlehook_surfaces_only',
    };
  }

  return {
    managerMode: MANAGER_MODE_NONE,
    managerViewCompatible: false,
    metadataAutoWriteSupported: false,
    keeperRequired: true,
    reason: 'required_manager_surfaces_unavailable',
  };
}

async function preflightEnsJobPagesTarget(target, manager, probeJobId = 0) {
  const compatibility = await detectManagerCompatibility(manager, probeJobId);
  const result = {
    target,
    manager,
    ...compatibility,
    targetReachable: false,
    targetJobManagerReadable: false,
    targetJobManager: ethers.ZeroAddress,
    targetValidationReadable: false,
    targetValidationMask: null,
    legacyHandleHookCallable: false,
    typedHooksCallable: false,
  };

  if (!(await hasCode(target))) {
    result.reason = 'ens_target_missing_code';
    return result;
  }

  result.targetReachable = true;
  const pages = new ethers.Contract(target, ENS_JOB_PAGES_ABI, ethers.provider);

  try {
    const jm = await pages.jobManager();
    result.targetJobManagerReadable = true;
    result.targetJobManager = jm;
  } catch (_) {}

  try {
    const mask = await pages.validateConfiguration();
    result.targetValidationReadable = true;
    result.targetValidationMask = Number(mask);
  } catch (_) {}

  result.legacyHandleHookCallable = await callSupports(target, 'handleHook(uint8,uint256)', [0, probeJobId], manager);
  result.typedHooksCallable = await callSupports(target, 'onJobCreated(uint256,address,string)', [probeJobId, ethers.ZeroAddress, ''], manager);

  return result;
}

function assertSafeLockConfig(preflight) {
  if (!preflight.targetReachable) throw new Error('LOCK_CONFIG refused: ENSJobPages target is not reachable.');
  if (preflight.managerMode === MANAGER_MODE_NONE) {
    throw new Error('LOCK_CONFIG refused: manager compatibility mode unresolved (none). Fix manager wiring first.');
  }
  if (preflight.keeperRequired) {
    throw new Error(
      `LOCK_CONFIG refused: manager mode ${preflight.managerMode} is keeper-assisted (metadata auto-write unavailable). Keep config mutable until repair/cutover runbooks are complete.`
    );
  }
}

module.exports = {
  MANAGER_MODE_NONE,
  MANAGER_MODE_LEAN,
  MANAGER_MODE_RICH,
  detectManagerCompatibility,
  preflightEnsJobPagesTarget,
  assertSafeLockConfig,
};
