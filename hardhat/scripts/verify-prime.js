const fs = require('fs');
const path = require('path');
const { ethers, network, run } = require('hardhat');

const FQNS = {
  AGIJobManagerPrime: 'contracts/AGIJobManagerPrime.sol:AGIJobManagerPrime',
  AGIJobDiscoveryPrime: 'contracts/AGIJobDiscoveryPrime.sol:AGIJobDiscoveryPrime',
  UriUtils: 'contracts/utils/UriUtils.sol:UriUtils',
  BondMath: 'contracts/utils/BondMath.sol:BondMath',
  ReputationMath: 'contracts/utils/ReputationMath.sol:ReputationMath',
  ENSOwnership: 'contracts/utils/ENSOwnership.sol:ENSOwnership',
  AGIJobCompletionNFT: 'contracts/periphery/AGIJobCompletionNFT.sol:AGIJobCompletionNFT',
};

function latestDeploymentRecord(networkName) {
  const dir = path.resolve(__dirname, '..', 'deployments', networkName);
  if (!fs.existsSync(dir)) throw new Error(`Missing deployments directory: ${dir}`);

  const candidates = fs
    .readdirSync(dir)
    .filter((name) => name.startsWith('deployment.prime.') && name.endsWith('.json'))
    .map((name) => ({ name, mtimeMs: fs.statSync(path.join(dir, name)).mtimeMs }))
    .sort((a, b) => b.mtimeMs - a.mtimeMs);

  if (!candidates.length) throw new Error(`No prime deployment artifacts found in ${dir}`);
  return path.join(dir, candidates[0].name);
}

async function verifyContract({ name, address, constructorArguments = [], libraries = undefined }) {
  try {
    await run('verify:verify', { address, constructorArguments, libraries });
    return { name, status: 'verified' };
  } catch (error) {
    const message = String(error?.message || error);
    const lowered = message.toLowerCase();
    if (lowered.includes('already verified') || lowered.includes('already been verified')) {
      return { name, status: 'already_verified' };
    }
    return { name, status: 'failed', error: message };
  }
}

async function main() {
  const deploymentPath = process.env.DEPLOYMENT_ARTIFACT
    ? path.resolve(process.cwd(), process.env.DEPLOYMENT_ARTIFACT)
    : latestDeploymentRecord(network.name);

  const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
  const chainId = Number((await ethers.provider.getNetwork()).chainId);

  if (chainId !== Number(deployment.chainId)) {
    throw new Error(`Artifact chainId=${deployment.chainId} does not match connected chainId=${chainId}.`);
  }

  const managerArgs = deployment.managerConstructorArgs;
  const discoveryArgs = deployment.discoveryConstructorArgs;
  const libraries = deployment.libraries;

  const checks = [
    { name: 'UriUtils', constructorArguments: [], address: deployment.contracts?.UriUtils?.address },
    { name: 'BondMath', constructorArguments: [], address: deployment.contracts?.BondMath?.address },
    { name: 'ReputationMath', constructorArguments: [], address: deployment.contracts?.ReputationMath?.address },
    { name: 'ENSOwnership', constructorArguments: [], address: deployment.contracts?.ENSOwnership?.address },
    {
      name: 'AGIJobManagerPrime',
      constructorArguments: managerArgs,
      address: deployment.contracts?.AGIJobManagerPrime?.address,
      libraries,
    },
    {
      name: 'AGIJobDiscoveryPrime',
      constructorArguments: discoveryArgs,
      address: deployment.contracts?.AGIJobDiscoveryPrime?.address,
    },
    {
      name: 'AGIJobCompletionNFT',
      constructorArguments: [deployment.contracts?.AGIJobManagerPrime?.address],
      address: deployment.completionNFT,
    },
  ];

  const results = [];
  for (const check of checks) {
    if (!check.address || !ethers.isAddress(check.address)) {
      results.push({ name: check.name, status: 'skipped', error: 'missing address in deployment artifact' });
      continue;
    }
    results.push(
      await verifyContract({
        name: check.name,
        address: check.address,
        constructorArguments: check.constructorArguments,
        libraries: check.libraries,
      })
    );
  }

  console.log(`Verification artifact: ${deploymentPath}`);
  for (const result of results) {
    const suffix = result.error ? ` :: ${result.error}` : '';
    console.log(`${result.name} [${result.status}]${suffix}`);
  }

  const blockingFailures = results.filter(
    (result) => result.status !== 'verified' && result.status !== 'already_verified'
  );
  if (blockingFailures.length) {
    const failedNames = blockingFailures.map((item) => item.name).join(', ');
    throw new Error(`Prime verification failed for: ${failedNames}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
