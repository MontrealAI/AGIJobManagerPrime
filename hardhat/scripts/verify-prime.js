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
    await run('verify:verify', {
      address,
      constructorArguments,
      libraries,
      contract: FQNS[name],
    });
    return { name, status: 'verified' };
  } catch (error) {
    const message = String(error?.message || error);
    if (message.toLowerCase().includes('already verified')) return { name, status: 'already_verified' };
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
    ['UriUtils', []],
    ['BondMath', []],
    ['ReputationMath', []],
    ['ENSOwnership', []],
    ['AGIJobManagerPrime', managerArgs],
    ['AGIJobDiscoveryPrime', discoveryArgs],
  ];

  const results = [];
  for (const [name, constructorArguments] of checks) {
    const address = deployment.contracts?.[name]?.address;
    if (!address || !ethers.isAddress(address)) {
      results.push({ name, status: 'skipped', error: 'missing address in deployment artifact' });
      continue;
    }
    results.push(
      await verifyContract({
        name,
        address,
        constructorArguments,
        libraries: name === 'AGIJobManagerPrime' ? libraries : undefined,
      })
    );
  }

  console.log(`Verification artifact: ${deploymentPath}`);
  for (const result of results) {
    const suffix = result.error ? ` :: ${result.error}` : '';
    console.log(`${result.name} [${result.status}]${suffix}`);
  }

  const unsuccessful = results.filter((result) => result.status !== 'verified' && result.status !== 'already_verified');
  if (unsuccessful.length) {
    const failedNames = unsuccessful.map((result) => `${result.name}:${result.status}`).join(', ');
    throw new Error(`Prime verification incomplete. Unsuccessful targets: ${failedNames}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
