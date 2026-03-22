const hre = require("hardhat");
const { ethers } = hre;

function env(key) {
  const value = process.env[key];
  if (!value) throw new Error(`Missing required env ${key}`);
  return value;
}

async function main() {
  const managerAddress = env("JOB_MANAGER");
  const pagesAddress = env("ENS_JOB_PAGES");
  const rootName = ethers.ensNormalize(env("JOBS_ROOT_NAME"));
  const rootNode = env("JOBS_ROOT_NODE");
  const wrapperAddress = process.env.NAME_WRAPPER || ethers.ZeroAddress;

  const manager = await ethers.getContractAt(["function supportsInterface(bytes4) view returns (bool)"], managerAddress);
  const pages = await ethers.getContractAt([
    "function supportsInterface(bytes4) view returns (bool)",
    "function jobsRootName() view returns (string)",
    "function jobsRootNode() view returns (bytes32)",
    "function validateConfiguration() view returns (uint256)",
    "function isWrappedRootReady() view returns (bool)"
  ], pagesAddress);

  const managerIfaceId = "0xa82f6f45"; // IAGIJobManagerENSViewV1
  const pagesIfaceId = "0xd838c8bb";   // IENSJobPagesHooksV1

  if (!(await manager.supportsInterface(managerIfaceId))) throw new Error("JOB_MANAGER does not support IAGIJobManagerENSViewV1");
  if (!(await pages.supportsInterface(pagesIfaceId))) throw new Error("ENS_JOB_PAGES does not support IENSJobPagesHooksV1");

  if ((await pages.jobsRootName()) !== rootName) throw new Error("JOBS_ROOT_NAME mismatch on ENSJobPages");
  if ((await pages.jobsRootNode()).toLowerCase() !== rootNode.toLowerCase()) throw new Error("JOBS_ROOT_NODE mismatch on ENSJobPages");
  if (ethers.namehash(rootName).toLowerCase() !== rootNode.toLowerCase()) throw new Error("Provided root namehash mismatch");

  const issues = await pages.validateConfiguration();
  if (issues !== 0n) throw new Error(`ENSJobPages validateConfiguration() returned non-zero bitmask ${issues}`);

  if (wrapperAddress !== ethers.ZeroAddress) {
    const wrappedReady = await pages.isWrappedRootReady();
    if (!wrappedReady) throw new Error("Wrapped root is not approval-ready for ENSJobPages");
  }

  console.log("ENS cutover validation passed.");
}

main().catch((err) => {
  console.error(err.message || err);
  process.exitCode = 1;
});
