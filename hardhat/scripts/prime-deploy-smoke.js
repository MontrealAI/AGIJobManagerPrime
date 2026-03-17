const fs = require('fs');
const os = require('os');
const path = require('path');
const hre = require('hardhat');

function latestPrimeArtifact(networkName) {
  const dir = path.join(__dirname, '..', 'deployments', networkName);
  const entries = fs.existsSync(dir)
    ? fs
        .readdirSync(dir)
        .filter((name) => name.startsWith('deployment.prime.') && name.endsWith('.json'))
        .map((name) => ({ name, mtimeMs: fs.statSync(path.join(dir, name)).mtimeMs }))
        .sort((a, b) => b.mtimeMs - a.mtimeMs)
    : [];

  if (!entries.length) {
    throw new Error(`No prime deployment artifact found in ${dir}`);
  }

  return path.join(dir, entries[0].name);
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

  process.env.DEPLOY_CONFIG = configPath;
  process.env.CONFIRMATIONS = '1';

  try {
    // Reuse the current in-memory hardhat chain so the mock token address has deployed code.
    const { main: deployMain } = require('./deploy');
    await deployMain();

    const artifactPath = latestPrimeArtifact('hardhat');
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));

    requireAddress('AGIJobManagerPrime', artifact.contracts?.AGIJobManagerPrime?.address);
    requireAddress('AGIJobDiscoveryPrime', artifact.contracts?.AGIJobDiscoveryPrime?.address);
    requireAddress('completionNFT', artifact.completionNFT);

    if (artifact.setDiscoveryModule?.discoveryModule !== artifact.contracts.AGIJobDiscoveryPrime.address) {
      throw new Error('Manager discovery module wiring does not match deployed AGIJobDiscoveryPrime address.');
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
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
