// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "./IENSRegistry.sol";
import "./INameWrapper.sol";
import "./IPublicResolver.sol";
import "./IENSJobPagesHooksV1.sol";
import "../interfaces/IAGIJobManagerPrimeViewV1.sol";

interface IResolverManager {
    function setResolver(bytes32 node, address resolver) external;
}

interface INameWrapperSubnameOwner {
    function setSubnodeOwner(
        bytes32 parentNode,
        string calldata label,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32);
}

contract ENSJobPages is Ownable, ERC1155Holder, IENSJobPagesHooksV1 {
    using Strings for uint256;

    error ENSNotConfigured();
    error ENSNotAuthorized();
    error InvalidParameters();
    error ConfigLocked();
    error JobLabelNotSnapshotted();
    error AuthorityNotEstablished();
    error EffectiveENSUnavailable(uint256 jobId);

    struct RootVersion {
        bytes32 rootNode;
        string rootName;
        uint64 activatedAt;
        bool normalized;
    }

    struct JobAuthority {
        bytes32 labelHash;
        uint32 rootVersionId;
        bytes32 rootNode;
        bytes32 node;
        uint64 authorityEstablishedAt;
        uint32 snapshotVersion;
        uint8 snapshotSource;
        bool authorityEstablished;
        bool legacyImported;
        bool finalized;
        bool fuseBurned;
    }

    uint256 private constant MAX_ROOT_NAME_LENGTH = 240;
    uint256 public constant ENS_JOB_PAGES_INTERFACE_VERSION = 2;
    uint256 private constant MAX_JOB_LABEL_PREFIX_LENGTH = 32;
    uint256 private constant MAX_ENS_LABEL_LENGTH = 63;
    uint256 private constant ENS_READ_GAS_LIMIT = 50_000;

    bytes4 private constant ENS_OWNER_SELECTOR = bytes4(keccak256("owner(bytes32)"));
    bytes4 private constant ENS_RESOLVER_SELECTOR = bytes4(keccak256("resolver(bytes32)"));
    bytes4 private constant WRAPPER_OWNER_OF_SELECTOR = bytes4(keccak256("ownerOf(uint256)"));
    bytes4 private constant WRAPPER_GET_APPROVED_SELECTOR = bytes4(keccak256("getApproved(uint256)"));
    bytes4 private constant WRAPPER_IS_APPROVED_FOR_ALL_SELECTOR = bytes4(keccak256("isApprovedForAll(address,address)"));
    bytes4 private constant SUPPORTS_INTERFACE_SELECTOR = bytes4(keccak256("supportsInterface(bytes4)"));

    bytes4 private constant RESOLVER_TEXT_INTERFACE_ID = 0x59d1d43c;
    bytes4 private constant RESOLVER_SETTEXT_INTERFACE_ID = 0x10f13a8c;
    bytes4 private constant RESOLVER_SETAUTH_INTERFACE_ID = 0x304e6ade;

    uint8 private constant HOOK_CREATE = 1;
    uint8 private constant HOOK_ASSIGN = 2;
    uint8 private constant HOOK_COMPLETION = 3;
    uint8 private constant HOOK_REVOKE = 4;
    uint8 private constant HOOK_LOCK = 5;
    uint8 private constant HOOK_LOCK_BURN = 6;

    uint8 public constant SNAPSHOT_SOURCE_CREATE = 1;
    uint8 public constant SNAPSHOT_SOURCE_LEGACY_IMPORT = 2;
    uint8 public constant SNAPSHOT_SOURCE_LEGACY_ADOPT = 3;
    uint8 public constant SNAPSHOT_SOURCE_REPAIR = 4;

    uint32 private constant CANNOT_UNWRAP = 1;
    uint32 private constant CANNOT_SET_RESOLVER = 1 << 3;
    uint32 private constant CANNOT_SET_TTL = 1 << 4;
    uint32 private constant PARENT_CANNOT_CONTROL = 1 << 16;
    uint32 private constant LOCK_FUSES =
        CANNOT_UNWRAP |
        PARENT_CANNOT_CONTROL |
        CANNOT_SET_RESOLVER |
        CANNOT_SET_TTL;

    event JobENSPageCreated(uint256 indexed jobId, bytes32 indexed node);
    event JobENSPermissionsUpdated(uint256 indexed jobId, address indexed account, bool isAuthorised);
    event JobENSLocked(uint256 indexed jobId, bytes32 indexed node, bool fusesBurned);
    event ENSRegistryUpdated(address indexed oldEns, address indexed newEns);
    event NameWrapperUpdated(address indexed oldNameWrapper, address indexed newNameWrapper);
    event PublicResolverUpdated(address indexed oldResolver, address indexed newResolver);
    event JobsRootUpdated(
        bytes32 indexed oldRootNode,
        bytes32 indexed newRootNode,
        string oldRootName,
        string newRootName
    );
    event RootVersionRegistered(uint256 indexed rootVersionId, bytes32 indexed rootNode, string rootName, bool normalized);
    event JobAuthoritySnapshotted(
        uint256 indexed jobId,
        bytes32 indexed node,
        string label,
        uint256 rootVersionId,
        uint8 snapshotSource,
        bool legacyImported
    );
    event JobManagerUpdated(address indexed oldJobManager, address indexed newJobManager);
    event UseEnsJobTokenURIUpdated(bool oldValue, bool newValue);
    event ENSHookProcessed(uint8 indexed hook, uint256 indexed jobId, bool configured, bool success);
    event ENSHookSkipped(uint8 indexed hook, uint256 indexed jobId, bytes32 indexed reason);
    event ENSHookBestEffortFailure(uint8 indexed hook, uint256 indexed jobId, bytes32 indexed operation);
    event ConfigurationLocked(address indexed locker);
    event JobLabelPrefixUpdated(string oldPrefix, string newPrefix);
    event LegacyJobPageMigrated(
        uint256 indexed jobId,
        bytes32 indexed node,
        string label,
        bool adopted,
        bool created
    );

    IENSRegistry public ens;
    INameWrapper public nameWrapper;
    IPublicResolver public publicResolver;
    bytes32 public jobsRootNode;
    string public jobsRootName;
    address public jobManager;
    bool public useEnsJobTokenURI;
    bool public configLocked;
    string public jobLabelPrefix;
    uint32 public currentSnapshotVersion = 1;
    uint256 public rootVersionCount;
    uint256 public currentRootVersionId;

    mapping(uint256 => string) private _jobLabelById;
    mapping(uint256 => bool) private _jobLabelIsSet;
    mapping(bytes32 => uint256) private _jobIdPlusOneByLabelHash;
    mapping(uint256 => bool) private _jobResolverConfigured;
    mapping(uint256 => bool) private _jobCompletionTextConfigured;
    mapping(uint256 => RootVersion) private _rootVersions;
    mapping(uint256 => JobAuthority) private _jobAuthority;

    uint256 private constant CONFIG_OK = 0;
    uint256 private constant CONFIG_ERR_ENS = 1 << 0;
    uint256 private constant CONFIG_ERR_RESOLVER = 1 << 1;
    uint256 private constant CONFIG_ERR_ROOT = 1 << 2;
    uint256 private constant CONFIG_ERR_ROOT_OWNER = 1 << 3;
    uint256 private constant CONFIG_ERR_WRAPPER_APPROVAL = 1 << 4;
    uint256 private constant CONFIG_ERR_JOB_MANAGER = 1 << 5;
    uint256 private constant CONFIG_ERR_ROOT_NAMEHASH = 1 << 6;
    uint256 private constant CONFIG_ERR_RESOLVER_TEXT = 1 << 7;
    uint256 private constant CONFIG_ERR_RESOLVER_SETTEXT = 1 << 8;
    uint256 private constant CONFIG_ERR_RESOLVER_SETAUTH = 1 << 9;

    constructor(
        address ensAddress,
        address nameWrapperAddress,
        address publicResolverAddress,
        bytes32 rootNode,
        string memory rootName
    ) {
        if (ensAddress == address(0) || ensAddress.code.length == 0) revert InvalidParameters();
        if (publicResolverAddress == address(0) || publicResolverAddress.code.length == 0) revert InvalidParameters();
        if (nameWrapperAddress != address(0) && nameWrapperAddress.code.length == 0) revert InvalidParameters();

        bool hasRootNode = rootNode != bytes32(0);
        bool hasRootName = bytes(rootName).length != 0;
        if (hasRootNode != hasRootName) revert InvalidParameters();
        if (hasRootName && (!_isValidRootName(rootName) || _namehash(rootName) != rootNode)) revert InvalidParameters();

        ens = IENSRegistry(ensAddress);
        nameWrapper = INameWrapper(nameWrapperAddress);
        publicResolver = IPublicResolver(publicResolverAddress);
        jobsRootNode = rootNode;
        jobsRootName = rootName;
        jobLabelPrefix = "agijob-";

        if (hasRootName) {
            _registerRootVersion(rootNode, rootName);
        }
    }

    function setJobLabelPrefix(string calldata newPrefix) external onlyOwner {
        if (configLocked) revert ConfigLocked();
        if (!_isValidJobLabelPrefix(newPrefix)) revert InvalidParameters();

        string memory oldPrefix = jobLabelPrefix;
        jobLabelPrefix = newPrefix;
        emit JobLabelPrefixUpdated(oldPrefix, newPrefix);
    }

    function setENSRegistry(address ensAddress) external onlyOwner {
        if (configLocked) revert ConfigLocked();
        address old = address(ens);
        if (ensAddress == address(0) || ensAddress.code.length == 0) revert InvalidParameters();
        ens = IENSRegistry(ensAddress);
        emit ENSRegistryUpdated(old, ensAddress);
    }

    function setNameWrapper(address nameWrapperAddress) external onlyOwner {
        if (configLocked) revert ConfigLocked();
        address old = address(nameWrapper);
        if (nameWrapperAddress != address(0) && nameWrapperAddress.code.length == 0) revert InvalidParameters();
        nameWrapper = INameWrapper(nameWrapperAddress);
        emit NameWrapperUpdated(old, nameWrapperAddress);
    }

    function setPublicResolver(address publicResolverAddress) external onlyOwner {
        if (configLocked) revert ConfigLocked();
        address old = address(publicResolver);
        if (publicResolverAddress == address(0) || publicResolverAddress.code.length == 0) revert InvalidParameters();
        publicResolver = IPublicResolver(publicResolverAddress);
        emit PublicResolverUpdated(old, publicResolverAddress);
    }

    function ensJobPagesInterfaceVersion() external pure returns (uint256) {
        return ENS_JOB_PAGES_INTERFACE_VERSION;
    }

    function setJobsRoot(bytes32 rootNode, string calldata rootName) external onlyOwner {
        if (configLocked) revert ConfigLocked();
        bytes32 oldNode = jobsRootNode;
        string memory oldName = jobsRootName;
        if (rootNode == bytes32(0)) revert InvalidParameters();
        if (!_isValidRootName(rootName) || _namehash(rootName) != rootNode) revert InvalidParameters();
        jobsRootNode = rootNode;
        jobsRootName = rootName;
        _registerRootVersion(rootNode, rootName);
        emit JobsRootUpdated(oldNode, rootNode, oldName, rootName);
    }

    function setJobManager(address manager) external onlyOwner {
        if (configLocked) revert ConfigLocked();
        address old = jobManager;
        if (manager == address(0) || manager.code.length == 0) revert InvalidParameters();
        jobManager = manager;
        emit JobManagerUpdated(old, manager);
    }

    function setUseEnsJobTokenURI(bool enabled) external onlyOwner {
        if (configLocked) revert ConfigLocked();
        bool old = useEnsJobTokenURI;
        useEnsJobTokenURI = enabled;
        emit UseEnsJobTokenURIUpdated(old, enabled);
    }

    function lockConfiguration() external onlyOwner {
        if (!_isFullyConfigured()) revert ENSNotConfigured();
        configLocked = true;
        emit ConfigurationLocked(msg.sender);
    }

    modifier onlyJobManager() {
        if (msg.sender != jobManager) revert ENSNotAuthorized();
        _;
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) revert ENSNotAuthorized();
        _;
    }

    function previewJobEnsLabel(uint256 jobId) public view returns (string memory) {
        return _buildPreviewJobLabel(jobId);
    }

    function previewJobEnsName(uint256 jobId) public view returns (string memory) {
        if (!_isRootConfigured()) return "";
        return string(abi.encodePacked(previewJobEnsLabel(jobId), ".", jobsRootName));
    }

    function previewJobEnsURI(uint256 jobId) public view returns (string memory) {
        string memory ensName = previewJobEnsName(jobId);
        if (bytes(ensName).length == 0) return "";
        return string(abi.encodePacked("ens://", ensName));
    }

    function previewJobEnsNode(uint256 jobId) public view returns (bytes32) {
        if (!_isRootConfigured()) revert ENSNotConfigured();
        return keccak256(abi.encodePacked(jobsRootNode, keccak256(bytes(previewJobEnsLabel(jobId)))));
    }

    function effectiveJobEnsLabel(uint256 jobId) public view returns (string memory) {
        if (!_jobAuthority[jobId].authorityEstablished) revert EffectiveENSUnavailable(jobId);
        return _jobLabelById[jobId];
    }

    function effectiveJobEnsName(uint256 jobId) public view returns (string memory) {
        JobAuthority memory authority = _jobAuthority[jobId];
        if (!authority.authorityEstablished) revert EffectiveENSUnavailable(jobId);
        return string(abi.encodePacked(_jobLabelById[jobId], ".", _rootVersions[authority.rootVersionId].rootName));
    }

    function effectiveJobEnsURI(uint256 jobId) public view returns (string memory) {
        return string(abi.encodePacked("ens://", effectiveJobEnsName(jobId)));
    }

    function effectiveJobEnsNode(uint256 jobId) public view returns (bytes32) {
        JobAuthority memory authority = _jobAuthority[jobId];
        if (!authority.authorityEstablished) revert EffectiveENSUnavailable(jobId);
        return authority.node;
    }

    /// @notice Compatibility getter. Returns authoritative values once established, otherwise the live preview projection.
    function jobEnsLabel(uint256 jobId) public view returns (string memory) {
        return _jobAuthority[jobId].authorityEstablished ? _jobLabelById[jobId] : previewJobEnsLabel(jobId);
    }

    function jobEnsName(uint256 jobId) public view returns (string memory) {
        if (_jobAuthority[jobId].authorityEstablished) {
            return effectiveJobEnsName(jobId);
        }
        return previewJobEnsName(jobId);
    }

    function jobEnsURI(uint256 jobId) external view returns (string memory) {
        if (_jobAuthority[jobId].authorityEstablished) {
            return effectiveJobEnsURI(jobId);
        }
        return previewJobEnsURI(jobId);
    }

    function jobEnsNode(uint256 jobId) public view returns (bytes32) {
        if (_jobAuthority[jobId].authorityEstablished) {
            return effectiveJobEnsNode(jobId);
        }
        return previewJobEnsNode(jobId);
    }

    function jobLabelSnapshot(uint256 jobId) external view returns (bool isSet, string memory label) {
        return (_jobLabelIsSet[jobId], _jobLabelById[jobId]);
    }

    function rootVersionInfo(uint256 rootVersionId)
        external
        view
        returns (bytes32 rootNode, string memory rootName, uint64 activatedAt, bool normalized)
    {
        RootVersion memory versionInfo = _rootVersions[rootVersionId];
        return (versionInfo.rootNode, versionInfo.rootName, versionInfo.activatedAt, versionInfo.normalized);
    }

    function jobAuthorityInfo(uint256 jobId)
        external
        view
        returns (
            bool authorityEstablished,
            string memory label,
            bytes32 labelHash,
            uint32 rootVersionId,
            bytes32 authoritativeRootNode,
            bytes32 authoritativeNode,
            uint8 snapshotSource,
            uint32 snapshotVersion,
            uint64 authorityEstablishedAt,
            bool legacyImported,
            bool finalized,
            bool fuseBurned
        )
    {
        JobAuthority memory authority = _jobAuthority[jobId];
        return (
            authority.authorityEstablished,
            _jobLabelById[jobId],
            authority.labelHash,
            authority.rootVersionId,
            authority.rootNode,
            authority.node,
            authority.snapshotSource,
            authority.snapshotVersion,
            authority.authorityEstablishedAt,
            authority.legacyImported,
            authority.finalized,
            authority.fuseBurned
        );
    }

    function isFullyConfigured() external view returns (bool) {
        return validateConfiguration() == CONFIG_OK;
    }

    function isWrappedRootReady() external view returns (bool) {
        return _isWrappedRoot() && _isWrapperAuthorizationReady();
    }

    function configurationStatus()
        external
        view
        returns (
            bool configured,
            bool locked,
            bool rootConfigured,
            bool rootNodeMatchesRootName,
            bool rootNormalized,
            bool wrappedRoot,
            bool wrapperAuthorizationReady,
            bool resolverSupportsText,
            bool resolverSupportsSetText,
            bool resolverSupportsAuthorisation,
            uint256 failureBitmap
        )
    {
        bool supportsText;
        bool supportsSetText;
        bool supportsSetAuthorisation;
        (supportsText, supportsSetText, supportsSetAuthorisation) = _resolverCapabilities();
        failureBitmap = validateConfiguration();
        configured = failureBitmap == CONFIG_OK;
        locked = configLocked;
        rootConfigured = _isRootConfigured();
        rootNodeMatchesRootName = rootConfigured && _namehash(jobsRootName) == jobsRootNode;
        rootNormalized = rootConfigured && _isValidRootName(jobsRootName);
        wrappedRoot = _isWrappedRoot();
        wrapperAuthorizationReady = wrappedRoot && _isWrapperAuthorizationReady();
        resolverSupportsText = supportsText;
        resolverSupportsSetText = supportsSetText;
        resolverSupportsAuthorisation = supportsSetAuthorisation;
    }

    function validateConfiguration() public view returns (uint256 failures) {
        if (address(ens) == address(0) || address(ens).code.length == 0) failures |= CONFIG_ERR_ENS;
        if (address(publicResolver) == address(0) || address(publicResolver).code.length == 0) failures |= CONFIG_ERR_RESOLVER;
        if (!_isRootConfigured()) failures |= CONFIG_ERR_ROOT;
        if (_isRootConfigured() && _namehash(jobsRootName) != jobsRootNode) failures |= CONFIG_ERR_ROOT_NAMEHASH;
        if (jobManager == address(0) || jobManager.code.length == 0) failures |= CONFIG_ERR_JOB_MANAGER;
        (bool ok, address rootOwner) = _tryRootOwner();
        if (!ok || rootOwner == address(0)) failures |= CONFIG_ERR_ROOT_OWNER;
        if (ok && rootOwner == address(nameWrapper) && !_isWrapperAuthorizationReady()) failures |= CONFIG_ERR_WRAPPER_APPROVAL;
        if (ok && rootOwner != address(0) && rootOwner != address(this) && rootOwner != address(nameWrapper)) failures |= CONFIG_ERR_ROOT_OWNER;
        (bool supportsText, bool supportsSetText, bool supportsSetAuthorisation) = _resolverCapabilities();
        if (!supportsText) failures |= CONFIG_ERR_RESOLVER_TEXT;
        if (!supportsSetText) failures |= CONFIG_ERR_RESOLVER_SETTEXT;
        if (!supportsSetAuthorisation) failures |= CONFIG_ERR_RESOLVER_SETAUTH;
    }

    function jobEnsPreview(uint256 jobId) external view returns (string memory) {
        return previewJobEnsName(jobId);
    }

    function jobEnsIssued(uint256 jobId) public view returns (bool) {
        return _jobAuthority[jobId].authorityEstablished && jobEnsExists(jobId) && _jobResolverConfigured[jobId];
    }

    function jobEnsReady(uint256 jobId) public view returns (bool) {
        return jobEnsIssued(jobId) && _jobCompletionTextConfigured[jobId];
    }

    function jobEnsExists(uint256 jobId) public view returns (bool) {
        if (!_jobAuthority[jobId].authorityEstablished) return false;
        return _nodeExists(_jobAuthority[jobId].node);
    }

    function jobEnsStatus(uint256 jobId)
        external
        view
        returns (
            string memory label,
            string memory name,
            string memory uri,
            bytes32 node,
            bool snapshotted,
            bool issued,
            address resolverAddress,
            address ownerAddress,
            uint256 configFailures
        )
    {
        configFailures = validateConfiguration();
        label = jobEnsLabel(jobId);
        snapshotted = _jobAuthority[jobId].authorityEstablished;
        name = snapshotted ? effectiveJobEnsName(jobId) : previewJobEnsName(jobId);
        uri = bytes(name).length == 0 ? "" : string(abi.encodePacked("ens://", name));
        if (_isRootConfigured()) {
            node = jobEnsNode(jobId);
            issued = jobEnsIssued(jobId);
            (, ownerAddress) = _tryNodeOwner(node);
            (, resolverAddress) = _tryResolver(node);
        }
    }

    function createJobPage(uint256 jobId, address employer, string memory specURI) public onlyOwner {
        _createJobPage(jobId, employer, specURI);
    }

    function migrateLegacyWrappedJobPage(uint256 jobId, string calldata exactLabel)
        external
        onlyOwner
        returns (bytes32 node)
    {
        _requireConfigured();
        if (jobManager == address(0)) revert ENSNotConfigured();

        _importExactJobLabel(jobId, exactLabel);
        string memory label = _jobLabelById[jobId];
        _establishAuthority(jobId, label, SNAPSHOT_SOURCE_LEGACY_IMPORT, true);

        string memory specURI = IAGIJobManagerPrimeViewV1(jobManager).getJobSpecURI(jobId);
        (address employer, address assignedAgent, bool allowAuth) = _jobAuthStateForMigration(jobId);
        if (employer == address(0)) revert InvalidParameters();
        string memory completionURI = IAGIJobManagerPrimeViewV1(jobManager).getJobCompletionURI(jobId);

        node = _jobAuthority[jobId].node;
        bool adopted;
        bool created;

        if (_nodeExists(node)) {
            if (!_nodeManagedBySelf(node)) {
                if (!_isWrappedRoot()) revert ENSNotAuthorized();
                _requireWrapperAuthorization();
                INameWrapperSubnameOwner(address(nameWrapper)).setSubnodeOwner(
                    _jobAuthority[jobId].rootNode,
                    label,
                    address(this),
                    0,
                    type(uint64).max
                );

                if (!_nodeManagedBySelf(node)) revert ENSNotAuthorized();
                adopted = true;
            }
        } else {
            node = _createSubname(label);
            emit JobENSPageCreated(jobId, node);
            created = true;
        }

        _setResolverBestEffort(HOOK_CREATE, jobId, node, address(publicResolver));
        _setAuthorisationBestEffort(HOOK_CREATE, jobId, node, employer, allowAuth);
        _setAuthorisationBestEffort(HOOK_CREATE, jobId, node, assignedAgent, allowAuth);
        _setTextBestEffort(HOOK_CREATE, jobId, node, "schema", "agijobmanager/v1");
        _setTextBestEffort(HOOK_CREATE, jobId, node, "agijobs.spec.public", specURI);
        _setTextBestEffort(HOOK_CREATE, jobId, node, "agijobs.completion.public", completionURI);

        emit LegacyJobPageMigrated(jobId, node, label, adopted, created);
    }

    function repairAuthoritySnapshot(uint256 jobId, string calldata exactLabel) external onlyOwner {
        if (!_isRootConfigured() || currentRootVersionId == 0) revert ENSNotConfigured();
        if (bytes(exactLabel).length != 0) {
            _importExactJobLabel(jobId, exactLabel);
        } else if (!_jobLabelIsSet[jobId]) {
            _snapshotJobLabel(jobId, previewJobEnsLabel(jobId));
        }
        _establishAuthority(jobId, _jobLabelById[jobId], SNAPSHOT_SOURCE_REPAIR, false);
    }

    function replayCreate(uint256 jobId) external onlyOwner {
        this._handleCreateHook(IAGIJobManagerPrimeViewV1(jobManager), jobId);
    }

    function replayAssign(uint256 jobId) external onlyOwner {
        this._handleAssignHook(IAGIJobManagerPrimeViewV1(jobManager), jobId);
    }

    function replayCompletion(uint256 jobId) external onlyOwner {
        this._handleCompletionHook(IAGIJobManagerPrimeViewV1(jobManager), jobId);
    }

    function replayRevoke(uint256 jobId) external onlyOwner {
        this._handleRevokeHook(IAGIJobManagerPrimeViewV1(jobManager), jobId);
    }

    function replayLock(uint256 jobId, bool burnFuses) external onlyOwner {
        this._handleLockHook(IAGIJobManagerPrimeViewV1(jobManager), jobId, burnFuses);
    }

    function repairResolver(uint256 jobId) external onlyOwner {
        _setResolverBestEffort(HOOK_CREATE, jobId, _resolvedJobNodeForWrite(jobId), address(publicResolver));
    }

    function repairTexts(uint256 jobId) external onlyOwner {
        string memory specURI = IAGIJobManagerPrimeViewV1(jobManager).getJobSpecURI(jobId);
        string memory completionURI = IAGIJobManagerPrimeViewV1(jobManager).getJobCompletionURI(jobId);
        bytes32 node = _resolvedJobNodeForWrite(jobId);
        _setTextBestEffort(HOOK_CREATE, jobId, node, "schema", "agijobmanager/v1");
        _setTextBestEffort(HOOK_CREATE, jobId, node, "agijobs.spec.public", specURI);
        _setTextBestEffort(HOOK_COMPLETION, jobId, node, "agijobs.completion.public", completionURI);
    }

    function repairAuthorisations(uint256 jobId) external onlyOwner {
        (address employer, address assignedAgent, bool allowAuth) = _jobAuthStateForMigration(jobId);
        bytes32 node = _resolvedJobNodeForWrite(jobId);
        _setAuthorisationBestEffort(HOOK_CREATE, jobId, node, employer, allowAuth);
        _setAuthorisationBestEffort(HOOK_CREATE, jobId, node, assignedAgent, allowAuth);
    }

    function _jobAuthStateForMigration(uint256 jobId)
        internal
        view
        returns (address employer, address assignedAgent, bool allowAuth)
    {
        bool completed;
        bool expired;
        (employer, assignedAgent, , , , completed, , expired, ) = IAGIJobManagerPrimeViewV1(jobManager).getJobCore(jobId);
        allowAuth = !(completed || expired);
    }

    function _createJobPage(uint256 jobId, address employer, string memory specURI) internal {
        if (employer == address(0)) revert InvalidParameters();
        _requireConfigured();

        string memory label = _jobLabelIsSet[jobId] ? _jobLabelById[jobId] : previewJobEnsLabel(jobId);
        if (!_jobLabelIsSet[jobId]) {
            _snapshotJobLabel(jobId, label);
        }
        _establishAuthority(jobId, label, SNAPSHOT_SOURCE_CREATE, false);

        bytes32 node = _jobAuthority[jobId].node;
        if (_nodeExists(node)) {
            if (!_nodeManagedBySelf(node)) revert ENSNotAuthorized();
        } else {
            node = _createSubname(label);
            emit JobENSPageCreated(jobId, node);
        }

        _setResolverBestEffort(HOOK_CREATE, jobId, node, address(publicResolver));
        _setAuthorisationBestEffort(HOOK_CREATE, jobId, node, employer, true);
        _setTextBestEffort(HOOK_CREATE, jobId, node, "schema", "agijobmanager/v1");
        _setTextBestEffort(HOOK_CREATE, jobId, node, "agijobs.spec.public", specURI);
    }

    function onJobCreated(uint256 jobId, address employer, string calldata specURI) external onlyJobManager {
        _createJobPage(jobId, employer, specURI);
        emit ENSHookProcessed(HOOK_CREATE, jobId, true, true);
    }

    function onJobAssigned(uint256 jobId, address employer, address agent) external onlyJobManager {
        employer;
        _onAgentAssigned(jobId, agent);
        emit ENSHookProcessed(HOOK_ASSIGN, jobId, true, true);
    }

    function onJobCompletionRequested(uint256 jobId, string calldata completionURI) external onlyJobManager {
        _onCompletionRequested(jobId, completionURI);
        emit ENSHookProcessed(HOOK_COMPLETION, jobId, true, true);
    }

    function onJobRevoked(uint256 jobId, address employer, address agent) external onlyJobManager {
        _revokePermissions(jobId, employer, agent);
        emit ENSHookProcessed(HOOK_REVOKE, jobId, true, true);
    }

    function onJobLocked(uint256 jobId, address employer, address agent, bool burnFuses) external onlyJobManager {
        _lockJobENS(jobId, employer, agent, burnFuses);
        emit ENSHookProcessed(burnFuses ? HOOK_LOCK_BURN : HOOK_LOCK, jobId, true, true);
    }

    function handleHook(uint8 hook, uint256 jobId) external onlyJobManager {
        if (!_isFullyConfigured()) {
            emit ENSHookSkipped(hook, jobId, "NOT_CONFIGURED");
            emit ENSHookProcessed(hook, jobId, false, false);
            return;
        }

        bool success;
        IAGIJobManagerPrimeViewV1 jobManagerView = IAGIJobManagerPrimeViewV1(msg.sender);

        if (hook == HOOK_CREATE) {
            try this._handleCreateHook(jobManagerView, jobId) { success = true; } catch { emit ENSHookSkipped(hook, jobId, "HOOK_REVERTED"); }
            emit ENSHookProcessed(hook, jobId, true, success);
            return;
        }
        if (hook == HOOK_ASSIGN) {
            try this._handleAssignHook(jobManagerView, jobId) { success = true; } catch { emit ENSHookSkipped(hook, jobId, "HOOK_REVERTED"); }
            emit ENSHookProcessed(hook, jobId, true, success);
            return;
        }
        if (hook == HOOK_COMPLETION) {
            try this._handleCompletionHook(jobManagerView, jobId) { success = true; } catch { emit ENSHookSkipped(hook, jobId, "HOOK_REVERTED"); }
            emit ENSHookProcessed(hook, jobId, true, success);
            return;
        }
        if (hook == HOOK_REVOKE) {
            try this._handleRevokeHook(jobManagerView, jobId) { success = true; } catch { emit ENSHookSkipped(hook, jobId, "HOOK_REVERTED"); }
            emit ENSHookProcessed(hook, jobId, true, success);
            return;
        }
        if (hook == HOOK_LOCK || hook == HOOK_LOCK_BURN) {
            bool burnFuses = hook == HOOK_LOCK_BURN;
            try this._handleLockHook(jobManagerView, jobId, burnFuses) { success = true; } catch { emit ENSHookSkipped(hook, jobId, "HOOK_REVERTED"); }
            emit ENSHookProcessed(hook, jobId, true, success);
            return;
        }

        emit ENSHookSkipped(hook, jobId, "UNKNOWN_HOOK");
        emit ENSHookProcessed(hook, jobId, true, false);
    }

    function _handleCreateHook(IAGIJobManagerPrimeViewV1 managerView, uint256 jobId) external onlySelf {
        string memory specURI = managerView.getJobSpecURI(jobId);
        (address employer, , , , , , , , ) = managerView.getJobCore(jobId);
        _createJobPage(jobId, employer, specURI);
    }

    function _handleAssignHook(IAGIJobManagerPrimeViewV1 managerView, uint256 jobId) external onlySelf {
        (, address agent, , , , , , , ) = managerView.getJobCore(jobId);
        _onAgentAssigned(jobId, agent);
    }

    function _handleCompletionHook(IAGIJobManagerPrimeViewV1 managerView, uint256 jobId) external onlySelf {
        string memory completionURI = managerView.getJobCompletionURI(jobId);
        _onCompletionRequested(jobId, completionURI);
    }

    function _handleRevokeHook(IAGIJobManagerPrimeViewV1 managerView, uint256 jobId) external onlySelf {
        try managerView.getJobCore(jobId) returns (address employer, address agent, uint256, uint256, uint256, bool, bool, bool, uint8) {
            _revokePermissions(jobId, employer, agent);
        } catch {
            _revokePermissions(jobId, address(0), address(0));
        }
    }

    function _handleLockHook(IAGIJobManagerPrimeViewV1 managerView, uint256 jobId, bool burnFuses) external onlySelf {
        try managerView.getJobCore(jobId) returns (address employer, address agent, uint256, uint256, uint256, bool, bool, bool, uint8) {
            _lockJobENS(jobId, employer, agent, burnFuses);
        } catch {
            _lockJobENS(jobId, address(0), address(0), burnFuses);
        }
    }

    function onAgentAssigned(uint256 jobId, address agent) public onlyOwner {
        _onAgentAssigned(jobId, agent);
    }

    function _onAgentAssigned(uint256 jobId, address agent) internal {
        if (agent == address(0)) revert InvalidParameters();
        _requireConfigured();
        bytes32 node = _resolvedJobNodeForWrite(jobId);
        _setAuthorisationBestEffort(HOOK_ASSIGN, jobId, node, agent, true);
    }

    function onCompletionRequested(uint256 jobId, string memory completionURI) public onlyOwner {
        _onCompletionRequested(jobId, completionURI);
    }

    function _onCompletionRequested(uint256 jobId, string memory completionURI) internal {
        _requireConfigured();
        bytes32 node = _resolvedJobNodeForWrite(jobId);
        _setTextBestEffort(HOOK_COMPLETION, jobId, node, "agijobs.completion.public", completionURI);
    }

    function revokePermissions(uint256 jobId, address employer, address agent) public onlyOwner {
        _revokePermissions(jobId, employer, agent);
    }

    function _revokePermissions(uint256 jobId, address employer, address agent) internal {
        _requireConfigured();
        bytes32 node = _resolvedJobNodeForWrite(jobId);
        _setAuthorisationBestEffort(HOOK_REVOKE, jobId, node, employer, false);
        _setAuthorisationBestEffort(HOOK_REVOKE, jobId, node, agent, false);
    }

    function lockJobENS(uint256 jobId, address employer, address agent, bool burnFuses) public onlyOwner {
        _lockJobENS(jobId, employer, agent, burnFuses);
    }

    function _lockJobENS(uint256 jobId, address employer, address agent, bool burnFuses) internal {
        _requireConfigured();
        bytes32 node = _resolvedJobNodeForWrite(jobId);
        uint8 hook = burnFuses ? HOOK_LOCK_BURN : HOOK_LOCK;

        _setAuthorisationBestEffort(hook, jobId, node, employer, false);
        _setAuthorisationBestEffort(hook, jobId, node, agent, false);

        bool fusesBurned = false;
        if (burnFuses && _isWrappedNode(node)) {
            if (_nodeManagedBySelf(node)) {
                bytes32 labelhash = keccak256(bytes(_jobLabelById[jobId]));
                try nameWrapper.setChildFuses(_jobAuthority[jobId].rootNode, labelhash, LOCK_FUSES, type(uint64).max) {
                    fusesBurned = true;
                } catch {
                    emit ENSHookBestEffortFailure(hook, jobId, "BURN_FUSES");
                }
            } else {
                emit ENSHookBestEffortFailure(hook, jobId, "BURN_FUSES");
            }
        }

        _jobAuthority[jobId].finalized = true;
        _jobAuthority[jobId].fuseBurned = fusesBurned;
        emit JobENSLocked(jobId, node, fusesBurned);
    }

    function _createSubname(string memory label) internal returns (bytes32 node) {
        bytes32 labelHash = keccak256(bytes(label));

        if (_isWrappedRoot()) {
            _requireWrapperAuthorization();
            INameWrapperSubnameOwner(address(nameWrapper)).setSubnodeOwner(
                _jobAuthorityForCurrentRoot().rootNode,
                label,
                address(this),
                0,
                type(uint64).max
            );
        } else {
            if (ens.owner(jobsRootNode) != address(this)) revert ENSNotAuthorized();
            ens.setSubnodeRecord(jobsRootNode, labelHash, address(this), address(0), 0);
        }

        node = keccak256(abi.encodePacked(jobsRootNode, labelHash));
    }

    function _setResolverBestEffort(uint8 hook, uint256 jobId, bytes32 node, address resolver) internal {
        if (resolver == address(0)) return;
        if (!_supportsResolverInterface(address(publicResolver), RESOLVER_SETTEXT_INTERFACE_ID)) {
            emit ENSHookBestEffortFailure(hook, jobId, "RESOLVER_SET_TEXT_UNSUPPORTED");
        }

        if (_isWrappedNode(node)) {
            try IResolverManager(address(nameWrapper)).setResolver(node, resolver) {
                _jobResolverConfigured[jobId] = true;
            } catch {
                emit ENSHookBestEffortFailure(hook, jobId, "SET_RESOLVER");
            }
            return;
        }

        try IResolverManager(address(ens)).setResolver(node, resolver) {
            _jobResolverConfigured[jobId] = true;
        } catch {
            emit ENSHookBestEffortFailure(hook, jobId, "SET_RESOLVER");
        }
    }

    function _setTextBestEffort(uint8 hook, uint256 jobId, bytes32 node, string memory key, string memory value) internal {
        if (bytes(value).length == 0) return;
        if (!_supportsResolverInterface(address(publicResolver), RESOLVER_SETTEXT_INTERFACE_ID)) {
            emit ENSHookBestEffortFailure(hook, jobId, "SET_TEXT_UNSUPPORTED");
            return;
        }
        try publicResolver.setText(node, key, value) {
            if (keccak256(bytes(key)) == keccak256(bytes("agijobs.completion.public"))) {
                _jobCompletionTextConfigured[jobId] = true;
            }
        } catch {
            emit ENSHookBestEffortFailure(hook, jobId, "SET_TEXT");
        }
    }

    function _setAuthorisationBestEffort(uint8 hook, uint256 jobId, bytes32 node, address account, bool authorised) internal {
        if (account == address(0)) return;
        if (!_supportsResolverInterface(address(publicResolver), RESOLVER_SETAUTH_INTERFACE_ID)) {
            emit ENSHookBestEffortFailure(hook, jobId, "SET_AUTH_UNSUPPORTED");
            return;
        }

        try publicResolver.setAuthorisation(node, account, authorised) {
            emit JobENSPermissionsUpdated(jobId, account, authorised);
        } catch {
            emit ENSHookBestEffortFailure(hook, jobId, "SET_AUTH");
        }
    }

    function _nodeExists(bytes32 node) internal view returns (bool) {
        (bool ok, address ownerAddress) = _tryNodeOwner(node);
        return ok && ownerAddress != address(0);
    }

    function _nodeManagedBySelf(bytes32 node) internal view returns (bool) {
        (bool ok, address ownerAddress) = _tryNodeOwner(node);
        if (!ok || ownerAddress == address(0)) return false;
        if (ownerAddress == address(this)) return true;
        if (ownerAddress != address(nameWrapper)) return false;
        (ok, ownerAddress) = _staticcallAddress(address(nameWrapper), abi.encodeWithSelector(WRAPPER_OWNER_OF_SELECTOR, uint256(node)));
        return ok && ownerAddress == address(this);
    }

    function _isWrappedRoot() internal view returns (bool) {
        if (address(nameWrapper) == address(0)) return false;
        (bool ok, address ownerAddress) = _tryRootOwner();
        return ok && ownerAddress == address(nameWrapper);
    }

    function _isWrappedNode(bytes32 node) internal view returns (bool) {
        if (address(nameWrapper) == address(0)) return false;
        (bool ok, address ownerAddress) = _tryNodeOwner(node);
        return ok && ownerAddress == address(nameWrapper);
    }

    function _requireWrapperAuthorization() internal view {
        uint256 rootTokenId = uint256(jobsRootNode);
        (bool ok, address wrappedOwner) = _staticcallAddress(address(nameWrapper), abi.encodeWithSelector(WRAPPER_OWNER_OF_SELECTOR, rootTokenId));
        if (!ok || wrappedOwner == address(0)) revert ENSNotAuthorized();
        if (wrappedOwner == address(this)) return;
        address approved;
        (ok, approved) = _staticcallAddress(address(nameWrapper), abi.encodeWithSelector(WRAPPER_GET_APPROVED_SELECTOR, rootTokenId));
        if (ok && approved == address(this)) return;
        bool approvedForAll;
        (ok, approvedForAll) = _staticcallBool(address(nameWrapper), abi.encodeWithSelector(WRAPPER_IS_APPROVED_FOR_ALL_SELECTOR, wrappedOwner, address(this)));
        if (!ok || !approvedForAll) revert ENSNotAuthorized();
    }

    function _requireConfigured() internal view {
        if (address(ens) == address(0)) revert ENSNotConfigured();
        if (address(publicResolver) == address(0)) revert ENSNotConfigured();
        if (!_isRootConfigured()) revert ENSNotConfigured();
    }

    function _isFullyConfigured() internal view returns (bool) {
        if (address(ens) == address(0)) return false;
        if (address(publicResolver) == address(0)) return false;
        if (!_isRootConfigured()) return false;
        if (jobManager == address(0)) return false;
        if (validateConfiguration() != CONFIG_OK) return false;
        (bool ok, address rootOwner) = _tryRootOwner();
        if (!ok) return false;
        if (rootOwner == address(this)) return true;
        if (address(nameWrapper) == address(0) || rootOwner != address(nameWrapper)) return false;
        return _isWrapperAuthorizationReady();
    }

    function _isWrapperAuthorizationReady() internal view returns (bool) {
        uint256 rootTokenId = uint256(jobsRootNode);
        (bool ok, address wrappedOwner) = _staticcallAddress(address(nameWrapper), abi.encodeWithSelector(WRAPPER_OWNER_OF_SELECTOR, rootTokenId));
        if (!ok || wrappedOwner == address(0)) return false;
        if (wrappedOwner == address(this)) return true;
        address approved;
        (ok, approved) = _staticcallAddress(address(nameWrapper), abi.encodeWithSelector(WRAPPER_GET_APPROVED_SELECTOR, rootTokenId));
        if (ok && approved == address(this)) return true;
        bool approvedForAll;
        (ok, approvedForAll) = _staticcallBool(address(nameWrapper), abi.encodeWithSelector(WRAPPER_IS_APPROVED_FOR_ALL_SELECTOR, wrappedOwner, address(this)));
        return ok && approvedForAll;
    }

    function _isRootConfigured() internal view returns (bool) {
        return jobsRootNode != bytes32(0) && bytes(jobsRootName).length != 0;
    }

    function _isValidRootName(string memory rootName) internal pure returns (bool) {
        bytes memory raw = bytes(rootName);
        uint256 len = raw.length;
        if (len == 0 || len > MAX_ROOT_NAME_LENGTH) return false;
        if (raw[0] == bytes1(".") || raw[len - 1] == bytes1(".")) return false;
        bool lastWasDot = true;
        for (uint256 i = 0; i < len; i++) {
            bytes1 ch = raw[i];
            bool isDigit = ch >= bytes1("0") && ch <= bytes1("9");
            bool isLower = ch >= bytes1("a") && ch <= bytes1("z");
            bool isHyphen = ch == bytes1("-");
            bool isDot = ch == bytes1(".");
            if (!isDigit && !isLower && !isHyphen && !isDot) return false;
            if (isDot) {
                if (lastWasDot) return false;
                lastWasDot = true;
            } else {
                lastWasDot = false;
            }
        }
        return !lastWasDot;
    }

    function _isValidJobLabelPrefix(string memory prefix) internal pure returns (bool) {
        bytes memory raw = bytes(prefix);
        uint256 len = raw.length;
        if (len == 0 || len > MAX_JOB_LABEL_PREFIX_LENGTH) return false;
        if (raw[0] == bytes1("-")) return false;
        if (raw[len - 1] >= bytes1("0") && raw[len - 1] <= bytes1("9")) return false;
        for (uint256 i = 0; i < len; i++) {
            bytes1 ch = raw[i];
            bool isDigit = ch >= bytes1("0") && ch <= bytes1("9");
            bool isLower = ch >= bytes1("a") && ch <= bytes1("z");
            bool isHyphen = ch == bytes1("-");
            if (!isDigit && !isLower && !isHyphen) return false;
        }
        return true;
    }

    function _buildJobLabel(string memory prefix, uint256 jobId) internal pure returns (string memory) {
        string memory label = string(abi.encodePacked(prefix, jobId.toString()));
        if (bytes(label).length > MAX_ENS_LABEL_LENGTH) revert InvalidParameters();
        return label;
    }

    function _isValidExactJobLabelForJob(uint256 jobId, string memory label) internal pure returns (bool) {
        bytes memory raw = bytes(label);
        uint256 len = raw.length;
        if (len == 0 || len > MAX_ENS_LABEL_LENGTH) return false;
        if (raw[0] == bytes1("-")) return false;
        bytes memory idRaw = bytes(jobId.toString());
        uint256 idLen = idRaw.length;
        if (idLen == 0 || idLen > len) return false;
        for (uint256 i = 0; i < len; i++) {
            bytes1 ch = raw[i];
            bool isDigit = ch >= bytes1("0") && ch <= bytes1("9");
            bool isLower = ch >= bytes1("a") && ch <= bytes1("z");
            bool isHyphen = ch == bytes1("-");
            if (!isDigit && !isLower && !isHyphen) return false;
        }
        uint256 suffixStart = len - idLen;
        for (uint256 i = 0; i < idLen; i++) {
            if (raw[suffixStart + i] != idRaw[i]) return false;
        }
        if (suffixStart > 0) {
            bytes1 prev = raw[suffixStart - 1];
            if (prev >= bytes1("0") && prev <= bytes1("9")) return false;
        }
        bytes memory prefixRaw = new bytes(suffixStart);
        for (uint256 i = 0; i < suffixStart; i++) prefixRaw[i] = raw[i];
        return _isValidJobLabelPrefix(string(prefixRaw));
    }

    function _buildPreviewJobLabel(uint256 jobId) internal view returns (string memory) {
        string memory label = _buildJobLabel(jobLabelPrefix, jobId);
        bytes32 labelHash = keccak256(bytes(label));
        uint256 existing = _jobIdPlusOneByLabelHash[labelHash];
        if (existing != 0 && existing != jobId + 1) revert InvalidParameters();
        return label;
    }

    function _resolvedJobNodeForWrite(uint256 jobId) internal view returns (bytes32) {
        if (!_jobAuthority[jobId].authorityEstablished) revert AuthorityNotEstablished();
        return _jobAuthority[jobId].node;
    }

    function _snapshotJobLabel(uint256 jobId, string memory label) internal {
        bytes32 labelHash = keccak256(bytes(label));
        uint256 existing = _jobIdPlusOneByLabelHash[labelHash];
        if (existing != 0 && existing != jobId + 1) revert InvalidParameters();
        _jobLabelById[jobId] = label;
        _jobLabelIsSet[jobId] = true;
        _jobIdPlusOneByLabelHash[labelHash] = jobId + 1;
    }

    function _importExactJobLabel(uint256 jobId, string memory label) internal {
        if (!_isValidExactJobLabelForJob(jobId, label)) revert InvalidParameters();
        if (_jobLabelIsSet[jobId]) {
            if (keccak256(bytes(_jobLabelById[jobId])) != keccak256(bytes(label))) revert InvalidParameters();
            return;
        }
        _snapshotJobLabel(jobId, label);
    }

    function _registerRootVersion(bytes32 rootNode, string memory rootName) internal {
        if (currentRootVersionId != 0) {
            RootVersion memory currentVersion = _rootVersions[currentRootVersionId];
            if (currentVersion.rootNode == rootNode && keccak256(bytes(currentVersion.rootName)) == keccak256(bytes(rootName))) {
                return;
            }
        }
        rootVersionCount += 1;
        currentRootVersionId = rootVersionCount;
        _rootVersions[currentRootVersionId] = RootVersion({
            rootNode: rootNode,
            rootName: rootName,
            activatedAt: uint64(block.timestamp),
            normalized: true
        });
        emit RootVersionRegistered(currentRootVersionId, rootNode, rootName, true);
    }

    function _establishAuthority(uint256 jobId, string memory label, uint8 snapshotSource, bool legacyImported) internal {
        if (!_isRootConfigured() || currentRootVersionId == 0) revert ENSNotConfigured();
        JobAuthority storage authority = _jobAuthority[jobId];
        if (authority.authorityEstablished) return;
        if (!_jobLabelIsSet[jobId]) revert JobLabelNotSnapshotted();
        authority.labelHash = keccak256(bytes(label));
        authority.rootVersionId = uint32(currentRootVersionId);
        authority.rootNode = jobsRootNode;
        authority.node = keccak256(abi.encodePacked(jobsRootNode, authority.labelHash));
        authority.authorityEstablishedAt = uint64(block.timestamp);
        authority.snapshotVersion = currentSnapshotVersion;
        authority.snapshotSource = snapshotSource;
        authority.authorityEstablished = true;
        authority.legacyImported = legacyImported;
        emit JobAuthoritySnapshotted(jobId, authority.node, label, currentRootVersionId, snapshotSource, legacyImported);
    }

    function _jobAuthorityForCurrentRoot() internal view returns (JobAuthority memory authority) {
        authority.rootNode = jobsRootNode;
    }

    function _tryRootOwner() internal view returns (bool ok, address ownerAddress) {
        return _tryNodeOwner(jobsRootNode);
    }

    function _tryNodeOwner(bytes32 node) internal view returns (bool ok, address ownerAddress) {
        return _staticcallAddress(address(ens), abi.encodeWithSelector(ENS_OWNER_SELECTOR, node));
    }

    function _tryResolver(bytes32 node) internal view returns (bool ok, address resolverAddress) {
        return _staticcallAddress(address(ens), abi.encodeWithSelector(ENS_RESOLVER_SELECTOR, node));
    }

    function _resolverCapabilities() internal view returns (bool supportsText, bool supportsSetText, bool supportsSetAuthorisation) {
        supportsText = _supportsResolverInterface(address(publicResolver), RESOLVER_TEXT_INTERFACE_ID);
        supportsSetText = _supportsResolverInterface(address(publicResolver), RESOLVER_SETTEXT_INTERFACE_ID);
        supportsSetAuthorisation = _supportsResolverInterface(address(publicResolver), RESOLVER_SETAUTH_INTERFACE_ID);
    }

    function _supportsResolverInterface(address resolver, bytes4 interfaceId) internal view returns (bool ok) {
        if (resolver == address(0) || resolver.code.length == 0) return false;
        bytes memory payload = abi.encodeWithSelector(SUPPORTS_INTERFACE_SELECTOR, interfaceId);
        (bool success, bytes memory data) = resolver.staticcall(payload);
        if (!success || data.length < 32) return false;
        ok = abi.decode(data, (bool));
    }

    function _staticcallAddress(address target, bytes memory payload) internal view returns (bool ok, address result) {
        uint256 decoded;
        (ok, decoded) = _staticcallWord(target, payload);
        if (!ok) return (false, address(0));
        result = address(uint160(decoded));
    }

    function _staticcallBool(address target, bytes memory payload) internal view returns (bool ok, bool result) {
        uint256 decoded;
        (ok, decoded) = _staticcallWord(target, payload);
        if (!ok || decoded > 1) return (false, false);
        result = decoded == 1;
    }

    function _staticcallWord(address target, bytes memory payload) internal view returns (bool ok, uint256 word) {
        assembly {
            ok := staticcall(ENS_READ_GAS_LIMIT, target, add(payload, 0x20), mload(payload), 0x00, 0x20)
            if lt(returndatasize(), 0x20) { ok := 0 }
            if ok {
                returndatacopy(0x00, 0x00, 0x20)
                word := mload(0x00)
            }
        }
    }

    function _namehash(string memory name) internal pure returns (bytes32 node) {
        bytes memory raw = bytes(name);
        if (raw.length == 0) return bytes32(0);
        uint256 end = raw.length;
        while (end > 0) {
            uint256 start = end;
            while (start > 0 && raw[start - 1] != bytes1(".")) { unchecked { --start; } }
            bytes memory label = new bytes(end - start);
            for (uint256 i = start; i < end; i++) label[i - start] = raw[i];
            node = keccak256(abi.encodePacked(node, keccak256(label)));
            if (start == 0) break;
            end = start - 1;
        }
    }
}
