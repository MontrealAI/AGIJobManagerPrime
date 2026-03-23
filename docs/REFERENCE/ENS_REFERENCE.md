# ENS Reference (Generated)

Generated at (UTC): 1970-01-01T00:00:00Z
Source fingerprint: f2bada7904c1499c

Source files used:
- `contracts/AGIJobManager.sol`
- `contracts/utils/ENSOwnership.sol`
- `contracts/ens/ENSJobPages.sol`
- `contracts/ens/IENSJobPages.sol`

## ENS surface area

- `bytes32 public clubRootNode;` ([contracts/AGIJobManager.sol#L394](../../contracts/AGIJobManager.sol#L394))
- `bytes32 public alphaClubRootNode;` ([contracts/AGIJobManager.sol#L395](../../contracts/AGIJobManager.sol#L395))
- `bytes32 public agentRootNode;` ([contracts/AGIJobManager.sol#L396](../../contracts/AGIJobManager.sol#L396))
- `bytes32 public alphaAgentRootNode;` ([contracts/AGIJobManager.sol#L397](../../contracts/AGIJobManager.sol#L397))
- `bytes32 public validatorMerkleRoot;` ([contracts/AGIJobManager.sol#L398](../../contracts/AGIJobManager.sol#L398))
- `bytes32 public agentMerkleRoot;` ([contracts/AGIJobManager.sol#L399](../../contracts/AGIJobManager.sol#L399))
- `ENS public ens;` ([contracts/AGIJobManager.sol#L400](../../contracts/AGIJobManager.sol#L400))
- `NameWrapper public nameWrapper;` ([contracts/AGIJobManager.sol#L401](../../contracts/AGIJobManager.sol#L401))
- `address public ensJobPages;` ([contracts/AGIJobManager.sol#L402](../../contracts/AGIJobManager.sol#L402))
- `bool public lockIdentityConfig;` ([contracts/AGIJobManager.sol#L405](../../contracts/AGIJobManager.sol#L405))
- `IENSRegistry public ens;` ([contracts/ens/ENSJobPages.sol#L141](../../contracts/ens/ENSJobPages.sol#L141))
- `INameWrapper public nameWrapper;` ([contracts/ens/ENSJobPages.sol#L142](../../contracts/ens/ENSJobPages.sol#L142))
- `IPublicResolver public publicResolver;` ([contracts/ens/ENSJobPages.sol#L143](../../contracts/ens/ENSJobPages.sol#L143))
- `bytes32 public jobsRootNode;` ([contracts/ens/ENSJobPages.sol#L144](../../contracts/ens/ENSJobPages.sol#L144))
- `string public jobsRootName;` ([contracts/ens/ENSJobPages.sol#L145](../../contracts/ens/ENSJobPages.sol#L145))
- `address public jobManager;` ([contracts/ens/ENSJobPages.sol#L146](../../contracts/ens/ENSJobPages.sol#L146))
- `bool public useEnsJobTokenURI;` ([contracts/ens/ENSJobPages.sol#L147](../../contracts/ens/ENSJobPages.sol#L147))
- `bool public configLocked;` ([contracts/ens/ENSJobPages.sol#L148](../../contracts/ens/ENSJobPages.sol#L148))
- `string public jobLabelPrefix;` ([contracts/ens/ENSJobPages.sol#L149](../../contracts/ens/ENSJobPages.sol#L149))

## Config and locks

- `function _initRoots(bytes32[4] memory rootNodes, bytes32[2] memory merkleRoots) internal` ([contracts/AGIJobManager.sol#L580](../../contracts/AGIJobManager.sol#L580))
- `function lockIdentityConfiguration() external onlyOwner whenIdentityConfigurable` ([contracts/AGIJobManager.sol#L738](../../contracts/AGIJobManager.sol#L738))
- `function applyForJob(uint256 _jobId, string memory subdomain, bytes32[] calldata proof)` ([contracts/AGIJobManager.sol#L770](../../contracts/AGIJobManager.sol#L770))
- `function validateJob(uint256 _jobId, string memory subdomain, bytes32[] calldata proof)` ([contracts/AGIJobManager.sol#L832](../../contracts/AGIJobManager.sol#L832))
- `function disapproveJob(uint256 _jobId, string memory subdomain, bytes32[] calldata proof)` ([contracts/AGIJobManager.sol#L840](../../contracts/AGIJobManager.sol#L840))
- `function updateAGITokenAddress(address _newTokenAddress) external onlyOwner whenIdentityConfigurable` ([contracts/AGIJobManager.sol#L1033](../../contracts/AGIJobManager.sol#L1033))
- `function updateEnsRegistry(address _newEnsRegistry) external onlyOwner whenIdentityConfigurable` ([contracts/AGIJobManager.sol#L1040](../../contracts/AGIJobManager.sol#L1040))
- `function updateNameWrapper(address _newNameWrapper) external onlyOwner whenIdentityConfigurable` ([contracts/AGIJobManager.sol#L1046](../../contracts/AGIJobManager.sol#L1046))
- `function setEnsJobPages(address _ensJobPages) external onlyOwner whenIdentityConfigurable` ([contracts/AGIJobManager.sol#L1052](../../contracts/AGIJobManager.sol#L1052))
- `function updateRootNodes(` ([contracts/AGIJobManager.sol#L1061](../../contracts/AGIJobManager.sol#L1061))
- `function updateMerkleRoots(bytes32 _validatorMerkleRoot, bytes32 _agentMerkleRoot)` ([contracts/AGIJobManager.sol#L1074](../../contracts/AGIJobManager.sol#L1074))
- `function lockJobENS(uint256 jobId, bool burnFuses) external` ([contracts/AGIJobManager.sol#L1293](../../contracts/AGIJobManager.sol#L1293))
- `function tokenURI(uint256 tokenId) public view override returns (string memory)` ([contracts/AGIJobManager.sol#L1529](../../contracts/AGIJobManager.sol#L1529))
- `function _callEnsJobPagesHook(uint8 hook, uint256 jobId) internal` ([contracts/AGIJobManager.sol#L1534](../../contracts/AGIJobManager.sol#L1534))
- `function setENSRegistry(address ensAddress) external onlyOwner` ([contracts/ens/ENSJobPages.sol#L211](../../contracts/ens/ENSJobPages.sol#L211))
- `function setNameWrapper(address nameWrapperAddress) external onlyOwner` ([contracts/ens/ENSJobPages.sol#L219](../../contracts/ens/ENSJobPages.sol#L219))
- `function setJobsRoot(bytes32 rootNode, string calldata rootName) external onlyOwner` ([contracts/ens/ENSJobPages.sol#L239](../../contracts/ens/ENSJobPages.sol#L239))
- `function lockConfiguration() external onlyOwner` ([contracts/ens/ENSJobPages.sol#L266](../../contracts/ens/ENSJobPages.sol#L266))
- `function handleHook(uint8 hook, uint256 jobId) external onlyJobManager` ([contracts/ens/ENSJobPages.sol#L755](../../contracts/ens/ENSJobPages.sol#L755))
- `function lockJobENS(uint256 jobId, address employer, address agent, bool burnFuses) public onlyOwner` ([contracts/ens/ENSJobPages.sol#L897](../../contracts/ens/ENSJobPages.sol#L897))
- `function _lockJobENS(uint256 jobId, address employer, address agent, bool burnFuses) internal` ([contracts/ens/ENSJobPages.sol#L901](../../contracts/ens/ENSJobPages.sol#L901))
- `function _createSubname(bytes32 parentRootNode, string memory label) internal returns (bytes32 node)` ([contracts/ens/ENSJobPages.sol#L928](../../contracts/ens/ENSJobPages.sol#L928))
- `function _isWrappedRootNode(bytes32 rootNode) internal view returns (bool)` ([contracts/ens/ENSJobPages.sol#L1008](../../contracts/ens/ENSJobPages.sol#L1008))
- `function _requireWrapperAuthorization(bytes32 rootNode) internal view` ([contracts/ens/ENSJobPages.sol#L1020](../../contracts/ens/ENSJobPages.sol#L1020))
- `function _registerRootVersion(bytes32 rootNode, string memory rootName) internal` ([contracts/ens/ENSJobPages.sol#L1173](../../contracts/ens/ENSJobPages.sol#L1173))
- `function verifyENSOwnership(` ([contracts/utils/ENSOwnership.sol#L32](../../contracts/utils/ENSOwnership.sol#L32))
- `function verifyENSOwnership(` ([contracts/utils/ENSOwnership.sol#L48](../../contracts/utils/ENSOwnership.sol#L48))
- `function verifyMerkleOwnership(address claimant, bytes32[] calldata proof, bytes32 merkleRoot)` ([contracts/utils/ENSOwnership.sol#L61](../../contracts/utils/ENSOwnership.sol#L61))

## Events and errors

- `error NotAuthorized();` ([contracts/AGIJobManager.sol#L333](../../contracts/AGIJobManager.sol#L333))
- `error InvalidParameters();` ([contracts/AGIJobManager.sol#L335](../../contracts/AGIJobManager.sol#L335))
- `error ConfigLocked();` ([contracts/AGIJobManager.sol#L344](../../contracts/AGIJobManager.sol#L344))
- `event EnsRegistryUpdated(address newEnsRegistry);` ([contracts/AGIJobManager.sol#L477](../../contracts/AGIJobManager.sol#L477))
- `event RootNodesUpdated(` ([contracts/AGIJobManager.sol#L479](../../contracts/AGIJobManager.sol#L479))
- `event MerkleRootsUpdated(bytes32 validatorMerkleRoot, bytes32 agentMerkleRoot);` ([contracts/AGIJobManager.sol#L485](../../contracts/AGIJobManager.sol#L485))
- `event IdentityConfigurationLocked(address indexed locker, uint256 indexed atTimestamp);` ([contracts/AGIJobManager.sol#L492](../../contracts/AGIJobManager.sol#L492))
- `event EnsJobPagesUpdated(address indexed oldEnsJobPages, address indexed newEnsJobPages);` ([contracts/AGIJobManager.sol#L499](../../contracts/AGIJobManager.sol#L499))
- `event EnsHookAttempted(uint8 indexed hook, uint256 indexed jobId, address indexed target, bool success);` ([contracts/AGIJobManager.sol#L514](../../contracts/AGIJobManager.sol#L514))
- `error ENSNotConfigured();` ([contracts/ens/ENSJobPages.sol#L31](../../contracts/ens/ENSJobPages.sol#L31))
- `error ENSNotAuthorized();` ([contracts/ens/ENSJobPages.sol#L32](../../contracts/ens/ENSJobPages.sol#L32))
- `error InvalidParameters();` ([contracts/ens/ENSJobPages.sol#L33](../../contracts/ens/ENSJobPages.sol#L33))
- `error EffectiveENSUnavailable(uint256 jobId);` ([contracts/ens/ENSJobPages.sol#L37](../../contracts/ens/ENSJobPages.sol#L37))
- `event JobENSPageCreated(uint256 indexed jobId, bytes32 indexed node);` ([contracts/ens/ENSJobPages.sol#L105](../../contracts/ens/ENSJobPages.sol#L105))
- `event JobENSPermissionsUpdated(uint256 indexed jobId, address indexed account, bool isAuthorised);` ([contracts/ens/ENSJobPages.sol#L106](../../contracts/ens/ENSJobPages.sol#L106))
- `event JobENSLocked(uint256 indexed jobId, bytes32 indexed node, bool fusesBurned);` ([contracts/ens/ENSJobPages.sol#L107](../../contracts/ens/ENSJobPages.sol#L107))
- `event ENSRegistryUpdated(address indexed oldEns, address indexed newEns);` ([contracts/ens/ENSJobPages.sol#L108](../../contracts/ens/ENSJobPages.sol#L108))
- `event UseEnsJobTokenURIUpdated(bool oldValue, bool newValue);` ([contracts/ens/ENSJobPages.sol#L127](../../contracts/ens/ENSJobPages.sol#L127))
- `event ENSHookProcessed(uint8 indexed hook, uint256 indexed jobId, bool configured, bool success);` ([contracts/ens/ENSJobPages.sol#L128](../../contracts/ens/ENSJobPages.sol#L128))
- `event ENSHookSkipped(uint8 indexed hook, uint256 indexed jobId, bytes32 indexed reason);` ([contracts/ens/ENSJobPages.sol#L129](../../contracts/ens/ENSJobPages.sol#L129))
- `event ENSHookBestEffortFailure(uint8 indexed hook, uint256 indexed jobId, bytes32 indexed operation);` ([contracts/ens/ENSJobPages.sol#L130](../../contracts/ens/ENSJobPages.sol#L130))

## Notes / caveats from code comments

- @notice Total AGI locked as agent performance bonds for unsettled jobs. ([contracts/AGIJobManager.sol#L386](../../contracts/AGIJobManager.sol#L386))
- @notice Total AGI locked as validator bonds for unsettled votes. ([contracts/AGIJobManager.sol#L388](../../contracts/AGIJobManager.sol#L388))
- @notice Total AGI locked as dispute bonds for unsettled disputes. ([contracts/AGIJobManager.sol#L390](../../contracts/AGIJobManager.sol#L390))
- @notice Freezes token/ENS/namewrapper/root nodes. Not a governance lock; ops remain owner-controlled. ([contracts/AGIJobManager.sol#L404](../../contracts/AGIJobManager.sol#L404))
- @notice Anyone may lock ENS records after a job reaches a terminal state; only the owner may burn fuses. ([contracts/AGIJobManager.sol#L1291](../../contracts/AGIJobManager.sol#L1291))
- @dev Fuse burning is irreversible and remains owner-only; ENS hook execution is best-effort. ([contracts/AGIJobManager.sol#L1292](../../contracts/AGIJobManager.sol#L1292))
- @dev as long as lockedEscrow/locked*Bonds are fully covered. ([contracts/AGIJobManager.sol#L1339](../../contracts/AGIJobManager.sol#L1339))
- @dev Owner withdrawals are limited to balances not backing lockedEscrow/locked*Bonds. ([contracts/AGIJobManager.sol#L1564](../../contracts/AGIJobManager.sol#L1564))

