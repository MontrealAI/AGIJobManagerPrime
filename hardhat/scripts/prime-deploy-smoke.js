const fs = require('fs');
const os = require('os');
const path = require('path');
const hre = require('hardhat');

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
