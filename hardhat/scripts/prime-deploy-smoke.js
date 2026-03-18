const fs = require('fs');
const os = require('os');
const path = require('path');
const hre = require('hardhat');

function listPrimeArtifacts(networkName) {
  const dir = path.join(__dirname, '..', 'deployments', networkName);
  const entries = fs.existsSync(dir)
    ? fs
        .readdirSync(dir)
        .filter((name) => name.startsWith('deployment.prime.') && name.endsWith('.json'))
        .map((name) => ({ name, mtimeMs: fs.statSync(path.join(dir, name)).mtimeMs }))
        .sort((a, b) => b.mtimeMs - a.mtimeMs)
    : [];

  return { dir, entries };
}

function artifactFromCurrentRun(networkName, beforeEntries) {
  const { dir, entries } = listPrimeArtifacts(networkName);

  if (!entries.length) {
    throw new Error(`No prime deployment artifact found in ${dir}`);
  }

  const beforeByName = new Map(beforeEntries.map((entry) => [entry.name, entry.mtimeMs]));
  const changedOrCreated = entries.filter((entry) => {
    const beforeMtime = beforeByName.get(entry.name);
    return beforeMtime === undefined || entry.mtimeMs > beforeMtime;
  });

  if (!changedOrCreated.length) {
    throw new Error(
      `No new Prime deployment artifact detected for this run in ${dir}; deploy may have skipped receipt output.`
    );
  }

  return path.join(dir, changedOrCreated[0].name);
}

function requireAddress(label, value) {
  if (!hre.ethers.isAddress(value) || value === hre.ethers.ZeroAddress) {
    throw new Error(`Invalid ${label}: ${String(value)}`);
  }
}

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  const mockToken = await hre.ethers.deployContract('MockERC20', []);
  await mockToken.waitForDeployment();

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'prime-smoke-'));
  const configPath = path.join(tempDir, 'deploy.config.js');

  const zero32 = `0x${'00'.repeat(32)}`;
  const configContents = `module.exports = {
  hardhat: {
    agiTokenAddress: '${await mockToken.getAddress()}',
    baseIpfsUrl: 'https://ipfs.io/ipfs/',
    ensConfig: ['${deployer.address}', '${deployer.address}'],
    rootNodes: ['${zero32}', '${zero32}', '${zero32}', '${zero32}'],
    merkleRoots: ['${zero32}', '${zero32}'],
    finalOwner: '${deployer.address}',
  },
};\n`;
  fs.writeFileSync(configPath, configContents, 'utf8');

  const previousDeployConfig = process.env.DEPLOY_CONFIG;
  const previousConfirmations = process.env.CONFIRMATIONS;
  const previousEnsJobPages = process.env.ENS_JOB_PAGES;

  process.env.DEPLOY_CONFIG = configPath;
  process.env.CONFIRMATIONS = '1';
  process.env.ENS_JOB_PAGES = await mockToken.getAddress();

  try {
    const { entries: beforeEntries } = listPrimeArtifacts('hardhat');

    // Reuse the current in-memory hardhat chain so the mock token address has deployed code.
    const { main: deployMain } = require('./deploy');
    await deployMain();

    const artifactPath = artifactFromCurrentRun('hardhat', beforeEntries);
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));

    requireAddress('AGIJobManagerPrime', artifact.contracts?.AGIJobManagerPrime?.address);
    requireAddress('AGIJobDiscoveryPrime', artifact.contracts?.AGIJobDiscoveryPrime?.address);
    requireAddress('completionNFT', artifact.completionNFT);

    if (artifact.setDiscoveryModule?.discoveryModule !== artifact.contracts.AGIJobDiscoveryPrime.address) {
      throw new Error('Manager discovery module wiring does not match deployed AGIJobDiscoveryPrime address.');
    }

    if (!artifact.setEnsJobPages?.executed || artifact.setEnsJobPages?.target !== await mockToken.getAddress()) {
      throw new Error('Expected ENS job pages wiring to execute in smoke run when ENS_JOB_PAGES is configured.');
    }

    console.log(`[smoke] verified artifact ${artifactPath}`);
    console.log(`[smoke] manager=${artifact.contracts.AGIJobManagerPrime.address}`);
    console.log(`[smoke] discovery=${artifact.contracts.AGIJobDiscoveryPrime.address}`);
    console.log(`[smoke] completionNFT=${artifact.completionNFT}`);
  } finally {
    if (previousDeployConfig === undefined) delete process.env.DEPLOY_CONFIG;
    else process.env.DEPLOY_CONFIG = previousDeployConfig;

    if (previousConfirmations === undefined) delete process.env.CONFIRMATIONS;
    else process.env.CONFIRMATIONS = previousConfirmations;

    if (previousEnsJobPages === undefined) delete process.env.ENS_JOB_PAGES;
    else process.env.ENS_JOB_PAGES = previousEnsJobPages;
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
