const fs = require('fs');
const path = require('path');
const { ethers, network, run } = require('hardhat');
const hardhatConfig = require('../hardhat.config');

const MAINNET_CONFIRMATION_VALUE = 'I_UNDERSTAND_MAINNET_DEPLOYMENT';
const DEFAULT_VERIFY_DELAY_MS = 3500;
const DEFAULT_VERIFY_RETRIES = 3;
const DEFAULT_CONFIRMATIONS = 3;

const MAX_MAINNET_RUNTIME_BYTES = 24_576;
const MAX_MAINNET_INITCODE_BYTES = 49_152;
const MANAGER_MODE_NONE = 'none';
const MANAGER_MODE_LEAN = 'lean';
const MANAGER_MODE_RICH = 'rich';

const FQNS = {
  AGIJobManagerPrime: 'contracts/AGIJobManagerPrime.sol:AGIJobManagerPrime',
  AGIJobDiscoveryPrime: 'contracts/AGIJobDiscoveryPrime.sol:AGIJobDiscoveryPrime',
  UriUtils: 'contracts/utils/UriUtils.sol:UriUtils',
  BondMath: 'contracts/utils/BondMath.sol:BondMath',
  ReputationMath: 'contracts/utils/ReputationMath.sol:ReputationMath',
  ENSOwnership: 'contracts/utils/ENSOwnership.sol:ENSOwnership',
};

const LIBRARIES = ['UriUtils', 'BondMath', 'ReputationMath', 'ENSOwnership'];
const SUPPORTED_NETWORKS = {
  mainnet: 1,
  sepolia: 11155111,
  hardhat: 31337,
  localhost: 31337,
};

function stableObject(value) {
  if (Array.isArray(value)) return value.map(stableObject);
  if (value && typeof value === 'object') {
    return Object.keys(value)
      .sort()
      .reduce((acc, key) => {
        acc[key] = stableObject(value[key]);
        return acc;
      }, {});
  }
  return value;
}

function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }

function getExplorerAddressBase(chainId) {
  if (chainId === 1) return 'https://etherscan.io/address/';
  if (chainId === 11155111) return 'https://sepolia.etherscan.io/address/';
  return null;
}

function getExplorerBase(chainId) {
  if (chainId === 1) return 'https://etherscan.io';
  if (chainId === 11155111) return 'https://sepolia.etherscan.io';
  return null;
}

function parsePositiveInt(value, label, fallback, min = 0) {
  if (value === undefined || value === null || value === '') return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min) {
    throw new Error(`${label} must be an integer >= ${min}. Received: ${value}`);
  }
  return parsed;
}

function validateExecutionNetwork(networkName, chainId) {
  const expectedChainId = SUPPORTED_NETWORKS[networkName];
  if (!expectedChainId) {
    throw new Error(
      `Unsupported network "${networkName}". Allowed networks: ${Object.keys(SUPPORTED_NETWORKS).join(', ')}`
    );
  }
  if (expectedChainId !== chainId) {
    throw new Error(`Network mismatch: network="${networkName}" expects chainId=${expectedChainId}, received chainId=${chainId}.`);
  }
}

function validateAddress(label, value, { allowZero = false } = {}) {
  if (!ethers.isAddress(value)) throw new Error(`${label} must be a valid address: ${String(value)}`);
  if (!allowZero && value.toLowerCase() === ethers.ZeroAddress.toLowerCase()) {
    throw new Error(`${label} must be non-zero: ${String(value)}`);
  }
}

function validateBytes32(label, value) {
  if (!ethers.isHexString(value, 32)) throw new Error(`${label} must be bytes32: ${String(value)}`);
}

async function callUintIfPresent(address, signature) {
  const selector = ethers.id(signature).slice(0, 10);
  try {
    const raw = await ethers.provider.call({ to: address, data: selector });
    if (!raw || raw === '0x' || raw.length < 66) return { ok: false, value: 0n };
    return { ok: true, value: BigInt(raw) };
  } catch {
    return { ok: false, value: 0n };
  }
}

async function surfaceReadable(address, signature, args = []) {
  try {
    const iface = new ethers.Interface([`function ${signature}`]);
    const data = iface.encodeFunctionData(signature.split('(')[0], args);
    const raw = await ethers.provider.call({ to: address, data });
    return !!raw && raw !== '0x';
  } catch {
    return false;
  }
}

async function classifyManagerCompatibility(managerAddress, probeJobId = 1n) {
  const version = await callUintIfPresent(managerAddress, 'ensJobManagerViewInterfaceVersion()');
  if (version.ok && version.value === 1n) {
    return {
      managerMode: MANAGER_MODE_RICH,
      managerViewCompatible: true,
      managerPushHookCompatible: true,
      keeperRequired: false,
      reason: 'manager declares IAGIJobManagerPrimeViewV1',
    };
  }

  const richReadable = await Promise.all([
    surfaceReadable(
      managerAddress,
      'getJobCore(uint256) view returns (address,address,uint256,uint256,uint256,bool,bool,bool,uint8)',
      [probeJobId]
    ),
    surfaceReadable(managerAddress, 'getJobSpecURI(uint256) view returns (string)', [probeJobId]),
    surfaceReadable(managerAddress, 'getJobCompletionURI(uint256) view returns (string)', [probeJobId]),
  ]);
  if (richReadable.every(Boolean)) {
    return {
      managerMode: MANAGER_MODE_RICH,
      managerViewCompatible: true,
      managerPushHookCompatible: true,
      keeperRequired: false,
      reason: 'manager rich view surfaces are readable',
    };
  }

  const leanReadable = await Promise.all([
    surfaceReadable(managerAddress, 'jobEmployerOf(uint256) view returns (address)', [probeJobId]),
    surfaceReadable(managerAddress, 'jobAssignedAgentOf(uint256) view returns (address)', [probeJobId]),
  ]);
  if (leanReadable.every(Boolean)) {
    return {
      managerMode: MANAGER_MODE_LEAN,
      managerViewCompatible: false,
      managerPushHookCompatible: true,
      keeperRequired: true,
      reason: 'manager exposes lean fallback read surfaces only',
    };
  }

  return {
    managerMode: MANAGER_MODE_NONE,
    managerViewCompatible: false,
    managerPushHookCompatible: false,
    keeperRequired: true,
    reason: 'manager does not expose rich or lean ENS-compatible read surfaces',
  };
}

async function preflightEnsWiring(managerAddress, ensJobPagesAddress) {
  const [managerCompat, targetValidationMask, targetJobManager] = await Promise.all([
    classifyManagerCompatibility(managerAddress, 1n),
    callUintIfPresent(ensJobPagesAddress, 'validateConfiguration()'),
    (async () => {
      try {
        const iface = new ethers.Interface(['function jobManager() view returns (address)']);
        const raw = await ethers.provider.call({
          to: ensJobPagesAddress,
          data: iface.encodeFunctionData('jobManager', []),
        });
        if (!raw || raw === '0x') return ethers.ZeroAddress;
        return iface.decodeFunctionResult('jobManager', raw)[0];
      } catch {
        return ethers.ZeroAddress;
      }
    })(),
  ]);

  const targetSupportsValidateConfiguration = targetValidationMask.ok;
  const validationMask = targetValidationMask.value;
  if (!targetSupportsValidateConfiguration) {
    throw new Error('ENS_JOB_PAGES target is not ENSJobPages-compatible (validateConfiguration unavailable).');
  }

  if (managerCompat.managerMode === MANAGER_MODE_NONE || !managerCompat.managerPushHookCompatible) {
    throw new Error(`Refusing ENS wiring: manager compatibility mode is unsafe (${managerCompat.managerMode}).`);
  }

  const expectedManager = managerAddress.toLowerCase();
  const observedManager = String(targetJobManager || ethers.ZeroAddress).toLowerCase();
  const managerAligned = observedManager === expectedManager;
  if (!managerAligned) {
    throw new Error(
      `Refusing ENS wiring: ENS_JOB_PAGES.jobManager (${targetJobManager}) does not match manager (${managerAddress}).`
    );
  }

  return {
    managerCompatibility: managerCompat,
    targetValidationMask: validationMask,
    targetSupportsValidateConfiguration,
    targetJobManager,
    managerAligned,
  };
}

function loadDeployConfig() {
  const configPath = process.env.DEPLOY_CONFIG
    ? path.resolve(process.cwd(), process.env.DEPLOY_CONFIG)
    : path.resolve(__dirname, '..', 'deploy.config.example.js');

  if (!fs.existsSync(configPath)) {
    throw new Error(`Deployment config file not found: ${configPath}`);
  }

  delete require.cache[configPath];
  // eslint-disable-next-line global-require, import/no-dynamic-require
  const config = require(configPath);
  return { config, configPath };
}

function resolvePrimeConstructor(networkName, profile) {
  if (!profile || typeof profile !== 'object') {
    throw new Error(`Missing deployment profile for network "${networkName}".`);
  }

  const constructorArgs = {
    agiTokenAddress: profile.agiTokenAddress,
    baseIpfsUrl: profile.baseIpfsUrl,
    ensConfig: profile.ensConfig,
    rootNodes: profile.rootNodes,
    merkleRoots: profile.merkleRoots,
  };

  validateAddress('agiTokenAddress', constructorArgs.agiTokenAddress);
  if (typeof constructorArgs.baseIpfsUrl !== 'string' || constructorArgs.baseIpfsUrl.trim() === '') {
    throw new Error('baseIpfsUrl must be a non-empty string.');
  }
  if (!Array.isArray(constructorArgs.ensConfig) || constructorArgs.ensConfig.length !== 2) {
    throw new Error('ensConfig must be an array of exactly 2 addresses: [ensRegistry, nameWrapper].');
  }
  if (!Array.isArray(constructorArgs.rootNodes) || constructorArgs.rootNodes.length !== 4) {
    throw new Error('rootNodes must be an array of exactly 4 bytes32 values.');
  }
  if (!Array.isArray(constructorArgs.merkleRoots) || constructorArgs.merkleRoots.length !== 2) {
    throw new Error('merkleRoots must be an array of exactly 2 bytes32 values.');
  }

  constructorArgs.ensConfig.forEach((value, index) => validateAddress(`ensConfig[${index}]`, value, { allowZero: index === 1 }));
  constructorArgs.rootNodes.forEach((value, index) => validateBytes32(`rootNodes[${index}]`, value));
  constructorArgs.merkleRoots.forEach((value, index) => validateBytes32(`merkleRoots[${index}]`, value));

  return constructorArgs;
}

function resolveFinalOwner(profile) {
  const finalOwner = process.env.FINAL_OWNER || profile.finalOwner;
  if (!finalOwner) {
    throw new Error('Unable to resolve finalOwner. Set FINAL_OWNER or config.finalOwner.');
  }
  validateAddress('finalOwner', finalOwner);
  return finalOwner;
}

async function deployContract(name, args = [], options = {}, confirmations = DEFAULT_CONFIRMATIONS) {
  const factory = await ethers.getContractFactory(name, options);
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  const tx = contract.deploymentTransaction();
  const receipt = await tx.wait(confirmations);

  return {
    name,
    address: await contract.getAddress(),
    txHash: tx.hash,
    blockNumber: receipt.blockNumber,
  };
}

async function verifyWithRetry(params, verifyDelayMs) {
  const { name, record } = params;
  const verificationEntry = { contract: name, status: 'pending', attempts: 0, error: null };

  for (let attempt = 1; attempt <= DEFAULT_VERIFY_RETRIES; attempt += 1) {
    verificationEntry.attempts = attempt;
    try {
      await run('verify:verify', {
        address: record.address,
        constructorArguments: params.constructorArguments || [],
        libraries: params.libraries,
        contract: FQNS[name],
      });
      verificationEntry.status = 'verified';
      verificationEntry.error = null;
      return verificationEntry;
    } catch (error) {
      const message = String(error?.message || error);
      const lowered = message.toLowerCase();
      if (lowered.includes('already verified') || lowered.includes('already been verified')) {
        verificationEntry.status = 'already_verified';
        verificationEntry.error = null;
        return verificationEntry;
      }
      verificationEntry.error = message;
      if (attempt < DEFAULT_VERIFY_RETRIES) await sleep(verifyDelayMs);
    }
  }

  verificationEntry.status = 'failed';
  return verificationEntry;
}

function getLatestBuildInfoPath() {
  const buildInfoDir = path.resolve(__dirname, '..', 'artifacts', 'build-info');
  if (!fs.existsSync(buildInfoDir)) {
    throw new Error(`Build info directory not found: ${buildInfoDir}. Run \`npx hardhat compile\` first.`);
  }
  const candidates = fs
    .readdirSync(buildInfoDir)
    .filter((fileName) => fileName.endsWith('.json'))
    .map((fileName) => {
      const fullPath = path.join(buildInfoDir, fileName);
      return { fullPath, mtimeMs: fs.statSync(fullPath).mtimeMs };
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs);

  if (!candidates.length) {
    throw new Error(`No build-info JSON files found in ${buildInfoDir}.`);
  }
  return candidates[0].fullPath;
}

function bytecodeHexToBytes(bytecode) {
  if (!bytecode || bytecode === '0x') return 0;
  const normalized = bytecode.startsWith('0x') ? bytecode.slice(2) : bytecode;
  return normalized.length / 2;
}

function encodePrimeConstructorArgs(constructorArgs) {
  const coder = ethers.AbiCoder.defaultAbiCoder();
  return coder.encode(
    ['address', 'string', 'address', 'address', 'bytes32[4]', 'bytes32[2]'],
    [
      constructorArgs.agiTokenAddress,
      constructorArgs.baseIpfsUrl,
      constructorArgs.ensConfig[0],
      constructorArgs.ensConfig[1],
      constructorArgs.rootNodes,
      constructorArgs.merkleRoots,
    ]
  );
}

function readPrimeBytecodeSizes(contractName, constructorEncodedBytes = 0) {
  const artifactPath = path.resolve(__dirname, '..', 'artifacts', 'contracts', `${contractName}.sol`, `${contractName}.json`);
  if (!fs.existsSync(artifactPath)) {
    throw new Error(`Missing ${contractName} artifact: ${artifactPath}. Run \`npm run compile\` first.`);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  const runtimeBytes = bytecodeHexToBytes(artifact.deployedBytecode);
  const initcodeTemplateBytes = bytecodeHexToBytes(artifact.bytecode);
  const initcodeBytes = initcodeTemplateBytes + constructorEncodedBytes;

  if (!runtimeBytes || !initcodeTemplateBytes) {
    throw new Error(`${contractName} artifact has empty bytecode; compile artifacts are invalid.`);
  }

  return {
    runtimeBytes,
    initcodeBytes,
    initcodeTemplateBytes,
    constructorArgsBytes: constructorEncodedBytes,
    runtimeHeadroom: MAX_MAINNET_RUNTIME_BYTES - runtimeBytes,
    initcodeHeadroom: MAX_MAINNET_INITCODE_BYTES - initcodeBytes,
  };
}

function copySolcInput(outDir) {
  const latestBuildInfoPath = getLatestBuildInfoPath();
  const buildInfo = JSON.parse(fs.readFileSync(latestBuildInfoPath, 'utf8'));
  const solcInputPath = path.join(outDir, 'solc-input.json');
  fs.writeFileSync(solcInputPath, `${JSON.stringify(buildInfo.input, null, 2)}\n`, 'utf8');
  return solcInputPath;
}

async function main() {
  const confirmations = parsePositiveInt(process.env.CONFIRMATIONS, 'CONFIRMATIONS', DEFAULT_CONFIRMATIONS, 1);
  const verifyDelayMs = parsePositiveInt(process.env.VERIFY_DELAY_MS, 'VERIFY_DELAY_MS', DEFAULT_VERIFY_DELAY_MS, 0);
  const shouldVerify = process.env.VERIFY === '1';
  const dryRun = process.env.DRY_RUN === '1';

  const [deployer] = await ethers.getSigners();
  const providerNetwork = await ethers.provider.getNetwork();
  const chainId = Number(providerNetwork.chainId);
  validateExecutionNetwork(network.name, chainId);
  const explorerBase = getExplorerBase(chainId);
  const explorerAddressBase = getExplorerAddressBase(chainId);

  const { config, configPath } = loadDeployConfig();
  const profile = config[network.name];
  const constructorArgs = resolvePrimeConstructor(network.name, profile);
  const resolvedFinalOwner = resolveFinalOwner(profile);

  const resolvedEnsJobPages = process.env.ENS_JOB_PAGES || profile.ensJobPages || '';
  if (resolvedEnsJobPages) validateAddress('ensJobPages', resolvedEnsJobPages);

  if (chainId === 1) {
    if (process.env.DEPLOY_CONFIRM_MAINNET !== MAINNET_CONFIRMATION_VALUE) {
      throw new Error(`Mainnet deployment blocked. Set DEPLOY_CONFIRM_MAINNET=${MAINNET_CONFIRMATION_VALUE}.`);
    }
    if (resolvedFinalOwner.toLowerCase() === ethers.ZeroAddress.toLowerCase()) {
      throw new Error('Mainnet deployment requires a non-zero finalOwner.');
    }
  }

  const managerBytecode = readPrimeBytecodeSizes('AGIJobManagerPrime', bytecodeHexToBytes(encodePrimeConstructorArgs(constructorArgs)));
  const discoveryBytecode = readPrimeBytecodeSizes('AGIJobDiscoveryPrime', bytecodeHexToBytes(ethers.AbiCoder.defaultAbiCoder().encode(['address'], [ethers.ZeroAddress])));

  for (const [name, result] of Object.entries({ AGIJobManagerPrime: managerBytecode, AGIJobDiscoveryPrime: discoveryBytecode })) {
    if (result.runtimeBytes > MAX_MAINNET_RUNTIME_BYTES) {
      throw new Error(`${name} runtime bytecode ${result.runtimeBytes} bytes exceeds mainnet limit (${MAX_MAINNET_RUNTIME_BYTES}).`);
    }
    if (result.initcodeBytes > MAX_MAINNET_INITCODE_BYTES) {
      throw new Error(`${name} initcode ${result.initcodeBytes} bytes exceeds EIP-3860 limit (${MAX_MAINNET_INITCODE_BYTES}).`);
    }
  }

  const plan = {
    network: network.name,
    chainId,
    deployer: deployer.address,
    finalOwner: resolvedFinalOwner,
    configPath,
    confirmations,
    verifyDelayMs,
    verifyEnabled: shouldVerify,
    constructorArgs,
    libraries: LIBRARIES,
    compiler: hardhatConfig.solidity,
    bytecode: { manager: managerBytecode, discovery: discoveryBytecode },
    steps: [
      'Deploy linked libraries',
      'Deploy AGIJobManagerPrime',
      'Deploy AGIJobDiscoveryPrime',
      'Wire manager.setDiscoveryModule(discovery)',
      'Optional setEnsJobPages(target)',
      'Transfer manager ownership (one-step) + initiate discovery two-step transfer',
      'Optional etherscan verification',
      'Persist deployment receipts + verify targets',
    ],
    dryRun,
  };

  console.log('=== Prime Deployment Plan ===');
  console.log(JSON.stringify(plan, null, 2));

  if (dryRun) {
    console.log('DRY_RUN=1 set; no transactions were broadcast.');
    return;
  }

  const deployments = {};
  const verificationResults = {};

  for (const libName of LIBRARIES) {
    const result = await deployContract(libName, [], {}, confirmations);
    deployments[libName] = result;
    console.log(`[deployed] ${libName} ${result.address} tx=${result.txHash}`);
  }

  const linkedLibraries = {
    [FQNS.UriUtils]: deployments.UriUtils.address,
    [FQNS.BondMath]: deployments.BondMath.address,
    [FQNS.ReputationMath]: deployments.ReputationMath.address,
    [FQNS.ENSOwnership]: deployments.ENSOwnership.address,
  };

  const managerArgs = [
    constructorArgs.agiTokenAddress,
    constructorArgs.baseIpfsUrl,
    constructorArgs.ensConfig[0],
    constructorArgs.ensConfig[1],
    constructorArgs.rootNodes,
    constructorArgs.merkleRoots,
  ];

  const managerDeployment = await deployContract('AGIJobManagerPrime', managerArgs, { libraries: linkedLibraries }, confirmations);
  deployments.AGIJobManagerPrime = managerDeployment;
  console.log(`[deployed] AGIJobManagerPrime ${managerDeployment.address} tx=${managerDeployment.txHash}`);

  const discoveryArgs = [managerDeployment.address];
  const discoveryDeployment = await deployContract(
    'AGIJobDiscoveryPrime',
    discoveryArgs,
    { libraries: { [FQNS.UriUtils]: deployments.UriUtils.address } },
    confirmations
  );
  deployments.AGIJobDiscoveryPrime = discoveryDeployment;
  console.log(`[deployed] AGIJobDiscoveryPrime ${discoveryDeployment.address} tx=${discoveryDeployment.txHash}`);

  const manager = await ethers.getContractAt('AGIJobManagerPrime', managerDeployment.address, deployer);
  const setDiscoveryTx = await manager.setDiscoveryModule(discoveryDeployment.address);
  const setDiscoveryReceipt = await setDiscoveryTx.wait(confirmations);
  const discoveryModuleWiring = {
    txHash: setDiscoveryTx.hash,
    blockNumber: setDiscoveryReceipt.blockNumber,
    discoveryModule: discoveryDeployment.address,
  };
  console.log(`[wired] AGIJobManagerPrime.setDiscoveryModule(${discoveryDeployment.address}) tx=${setDiscoveryTx.hash}`);

  let ensJobPagesWiring = { executed: false, txHash: null, blockNumber: null, target: null, reason: 'not_configured' };
  if (resolvedEnsJobPages) {
    const ensPreflight = await preflightEnsWiring(managerDeployment.address, resolvedEnsJobPages);
    console.log(
      `[preflight] ENS target=${resolvedEnsJobPages} mode=${ensPreflight.managerCompatibility.managerMode} keeperRequired=${ensPreflight.managerCompatibility.keeperRequired} validationMask=${ensPreflight.targetValidationMask}`
    );
    const setEnsTx = await manager.setEnsJobPages(resolvedEnsJobPages);
    const setEnsReceipt = await setEnsTx.wait(confirmations);
    ensJobPagesWiring = {
      executed: true,
      txHash: setEnsTx.hash,
      blockNumber: setEnsReceipt.blockNumber,
      target: resolvedEnsJobPages,
      managerCompatibility: ensPreflight.managerCompatibility,
      targetValidationMask: ensPreflight.targetValidationMask.toString(),
      reason: null,
    };
    console.log(`[wired] AGIJobManagerPrime.setEnsJobPages(${resolvedEnsJobPages}) tx=${setEnsTx.hash}`);
  } else {
    console.log('[wired] AGIJobManagerPrime.setEnsJobPages skipped (not configured).');
  }

  const completionNFTAddress = await manager.completionNFT();
  validateAddress('completionNFT', completionNFTAddress);
  console.log(`[derived] completionNFT ${completionNFTAddress}`);

  const discovery = await ethers.getContractAt('AGIJobDiscoveryPrime', discoveryDeployment.address, deployer);

  let ownershipTransfer = {
    executed: false,
    mode: 'none',
    reason: 'deployer_is_final_owner',
    contracts: [],
  };
  if (deployer.address.toLowerCase() !== resolvedFinalOwner.toLowerCase()) {
    const managerOwnerTx = await manager.transferOwnership(resolvedFinalOwner);
    const managerOwnerRcpt = await managerOwnerTx.wait(confirmations);

    const discoveryOwnerTx = await discovery.transferOwnership(resolvedFinalOwner);
    const discoveryOwnerRcpt = await discoveryOwnerTx.wait(confirmations);

    ownershipTransfer = {
      executed: true,
      mode: 'mixed_manager_one_step_discovery_two_step',
      reason: null,
      contracts: [
        { contract: 'AGIJobManagerPrime', txHash: managerOwnerTx.hash, blockNumber: managerOwnerRcpt.blockNumber, ownerAfterTx: resolvedFinalOwner },
        { contract: 'AGIJobDiscoveryPrime', txHash: discoveryOwnerTx.hash, blockNumber: discoveryOwnerRcpt.blockNumber, pendingOwner: resolvedFinalOwner },
      ],
      nextAction: `${resolvedFinalOwner} must call acceptOwnership() on AGIJobDiscoveryPrime`,
    };
    console.log(`[owner] AGIJobManagerPrime.transferOwnership(${resolvedFinalOwner}) tx=${managerOwnerTx.hash} (completed)`);
    console.log(`[owner] AGIJobDiscoveryPrime.transferOwnership(${resolvedFinalOwner}) tx=${discoveryOwnerTx.hash} (pending acceptance)`);
  } else {
    console.log('[owner] transferOwnership skipped (deployer is final owner).');
  }

  if (shouldVerify) {
    for (const libName of LIBRARIES) {
      await sleep(verifyDelayMs);
      verificationResults[libName] = await verifyWithRetry({ name: libName, record: deployments[libName] }, verifyDelayMs);
    }

    await sleep(verifyDelayMs);
    verificationResults.AGIJobManagerPrime = await verifyWithRetry(
      {
        name: 'AGIJobManagerPrime',
        record: managerDeployment,
        constructorArguments: managerArgs,
        libraries: linkedLibraries,
      },
      verifyDelayMs
    );

    await sleep(verifyDelayMs);
    verificationResults.AGIJobDiscoveryPrime = await verifyWithRetry(
      {
        name: 'AGIJobDiscoveryPrime',
        record: discoveryDeployment,
        constructorArguments: discoveryArgs,
        libraries: { [FQNS.UriUtils]: deployments.UriUtils.address },
      },
      verifyDelayMs
    );
  }

  const stablePayload = stableObject({ constructorArgs, libraries: linkedLibraries, finalOwner: resolvedFinalOwner });
  const configHash = ethers.keccak256(ethers.toUtf8Bytes(JSON.stringify(stablePayload)));

  const outDir = path.join(__dirname, '..', 'deployments', network.name);
  fs.mkdirSync(outDir, { recursive: true });

  const record = {
    chainId,
    network: network.name,
    explorerBaseUrl: explorerBase,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    finalOwner: resolvedFinalOwner,
    contracts: Object.fromEntries(
      Object.entries(deployments).map(([name, deployment]) => [name, {
        address: deployment.address,
        txHash: deployment.txHash,
        blockNumber: deployment.blockNumber,
      }])
    ),
    constructorArgs,
    managerConstructorArgs: managerArgs,
    discoveryConstructorArgs: discoveryArgs,
    libraries: linkedLibraries,
    setDiscoveryModule: discoveryModuleWiring,
    setEnsJobPages: ensJobPagesWiring,
    completionNFT: completionNFTAddress,
    pauseDefaults: {
      manager: {
        intakePaused: await manager.paused(),
        settlementPaused: await manager.settlementPaused(),
        emergencyPaused: await manager.paused(),
      },
      discovery: {
        intakePaused: await discovery.intakePaused(),
        settlementPaused: await manager.settlementPaused(),
        emergencyPaused: await discovery.paused(),
      },
    },
    ownershipTransfer,
    verification: shouldVerify ? verificationResults : { skipped: true },
    configHash,
    bytecode: { manager: managerBytecode, discovery: discoveryBytecode },
  };

  const receiptPath = path.join(outDir, `deployment.prime.${chainId}.${managerDeployment.blockNumber}.json`);
  fs.writeFileSync(receiptPath, `${JSON.stringify(record, null, 2)}\n`, 'utf8');

  const solcInputPath = copySolcInput(outDir);
  const verifyTargetsPath = path.join(outDir, 'verify-targets.prime.json');
  const verifyTargets = {
    network: network.name,
    chainId,
    targets: Object.entries(record.contracts).map(([name, contract]) => ({
      name,
      fqn: FQNS[name],
      address: contract.address,
    })),
  };
  fs.writeFileSync(verifyTargetsPath, `${JSON.stringify(verifyTargets, null, 2)}\n`, 'utf8');

  console.log('\n=== Prime Deployment Summary ===');
  Object.entries(record.contracts).forEach(([name, contract]) => {
    const explorerLink = explorerAddressBase ? ` ${explorerAddressBase}${contract.address}` : '';
    const verifyStatus = shouldVerify ? (verificationResults[name]?.status || 'not_attempted') : 'skipped';
    console.log(`${name}: ${contract.address}${explorerLink} [verify=${verifyStatus}]`);
  });
  console.log(`CompletionNFT: ${record.completionNFT}${explorerAddressBase ? ` ${explorerAddressBase}${record.completionNFT}` : ''}`);
  console.log(`setDiscoveryModule tx: ${discoveryModuleWiring.txHash}`);
  console.log(`setEnsJobPages: ${ensJobPagesWiring.executed ? `${ensJobPagesWiring.target} tx=${ensJobPagesWiring.txHash}` : 'skipped'}`);
  console.log(`pause defaults: manager[intake=${record.pauseDefaults.manager.intakePaused}, settlement=${record.pauseDefaults.manager.settlementPaused}, emergency=${record.pauseDefaults.manager.emergencyPaused}] discovery[intake=${record.pauseDefaults.discovery.intakePaused}, settlement=${record.pauseDefaults.discovery.settlementPaused}, emergency=${record.pauseDefaults.discovery.emergencyPaused}]`);
  if (ownershipTransfer.executed) {
    console.log(`pending ownership acceptance required: ${ownershipTransfer.nextAction}`);
  }
  console.log(`receipt: ${receiptPath}`);
  console.log(`solc-input: ${solcInputPath}`);
  console.log(`verify-targets: ${verifyTargetsPath}`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = { main };
