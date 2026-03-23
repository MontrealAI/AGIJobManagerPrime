// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IENSJobPagesInspectorTarget {
    function ens() external view returns (address);
    function publicResolver() external view returns (address);
    function nameWrapper() external view returns (address);
    function configLocked() external view returns (bool);
    function jobsRootNode() external view returns (bytes32);
    function jobManager() external view returns (address);
    function jobsRootName() external view returns (string memory);
    function previewJobEnsLabel(uint256 jobId) external view returns (string memory);
    function previewJobEnsName(uint256 jobId) external view returns (string memory);
    function previewJobEnsURI(uint256 jobId) external view returns (string memory);
    function previewJobEnsNode(uint256 jobId) external view returns (bytes32);
    function effectiveJobEnsLabel(uint256 jobId) external view returns (string memory);
    function effectiveJobEnsName(uint256 jobId) external view returns (string memory);
    function effectiveJobEnsURI(uint256 jobId) external view returns (string memory);
    function effectiveJobEnsNode(uint256 jobId) external view returns (bytes32);
    function validateConfiguration() external view returns (uint256);
    function configurationStatus() external view returns (bool,bool,bool,bool,bool,bool,bool,bool,bool,bool,uint256);
    function jobAuthorityInfo(uint256 jobId) external view returns (bool,string memory,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool);
}

interface IENSRegistryLite {
    function owner(bytes32 node) external view returns (address);
    function resolver(bytes32 node) external view returns (address);
}

interface INameWrapperLite {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract ENSJobPagesInspector {
    uint8 private constant MANAGER_MODE_NONE = 0;
    uint8 private constant MANAGER_MODE_LEAN = 1;
    uint8 private constant MANAGER_MODE_RICH = 2;

    struct JobStatusView {
        bool configured;
        bool configLocked;
        bool managerSupportsV1Views;
        bool metadataAutoWriteSupported;
        bool keeperRequired;
        bool rootConfigured;
        bool rootNodeMatchesRootName;
        bool rootNormalized;
        bool wrappedRoot;
        bool wrapperAuthorizationReady;
        bool resolverSupportsRequiredInterfaces;
        bool labelSnapshotted;
        bool rootSnapshotted;
        bool authoritySnapshotted;
        bool legacyImported;
        bool nodeExists;
        bool nodeManagedByContract;
        bool resolverSetToExpected;
        bool schemaTextPresent;
        bool specTextPresent;
        bool completionTextPresent;
        bool authReadSupported;
        bool employerAuthorisedObserved;
        bool agentAuthorisedObserved;
        bool authorisationsAsExpected;
        bool authObservationIncomplete;
        bool metadataComplete;
        bool previewReady;
        bool effectiveReady;
        bool finalizable;
        bool finalized;
        bool fuseBurned;
        uint8 managerMode;
        string previewLabel;
        string previewName;
        string previewURI;
        string effectiveLabel;
        string effectiveName;
        string effectiveURI;
        bytes32 effectiveNode;
        uint256 failureCode;
        uint256 metadataFailureCode;
    }

    function inspectJob(address target, uint256 jobId, address employer, address agent)
        external
        view
        returns (JobStatusView memory status)
    {
        IENSJobPagesInspectorTarget pages = IENSJobPagesInspectorTarget(target);
        (
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
        ) = pages.configurationStatus();

        (
            bool authorityEstablished,
            string memory label,
            ,
            ,
            bytes32 authoritativeRootNode,
            bytes32 authoritativeNode,
            ,
            ,
            ,
            bool legacyImported,
            bool finalized,
            bool fuseBurned
        ) = pages.jobAuthorityInfo(jobId);

        address manager = pages.jobManager();
        (status.managerSupportsV1Views, status.managerMode, status.metadataAutoWriteSupported, status.keeperRequired) =
            _managerCompatibility(manager, jobId);

        status.configured = configured;
        status.configLocked = locked;
        status.rootConfigured = rootConfigured;
        status.rootNodeMatchesRootName = rootNodeMatchesRootName;
        status.rootNormalized = rootNormalized;
        status.wrappedRoot = wrappedRoot;
        status.wrapperAuthorizationReady = wrapperAuthorizationReady;
        status.resolverSupportsRequiredInterfaces = resolverSupportsText && resolverSupportsSetText && resolverSupportsAuthorisation;
        status.labelSnapshotted = bytes(label).length != 0;
        status.rootSnapshotted = authorityEstablished && authoritativeRootNode != bytes32(0);
        status.authoritySnapshotted = authorityEstablished;
        status.legacyImported = legacyImported;
        status.finalized = finalized;
        status.fuseBurned = fuseBurned;
        status.previewLabel = pages.previewJobEnsLabel(jobId);
        status.previewName = pages.previewJobEnsName(jobId);
        status.previewURI = pages.previewJobEnsURI(jobId);
        status.previewReady = bytes(status.previewName).length != 0;
        status.failureCode = failureBitmap;

        if (authorityEstablished) {
            status.effectiveLabel = pages.effectiveJobEnsLabel(jobId);
            status.effectiveName = pages.effectiveJobEnsName(jobId);
            status.effectiveURI = pages.effectiveJobEnsURI(jobId);
            status.effectiveNode = pages.effectiveJobEnsNode(jobId);
            status.effectiveReady = bytes(status.effectiveName).length != 0;

            IENSRegistryLite ens = IENSRegistryLite(pages.ens());
            address nameWrapper = pages.nameWrapper();
            address nodeOwner = ens.owner(authoritativeNode);
            address nodeResolver = ens.resolver(authoritativeNode);
            status.nodeExists = nodeOwner != address(0);
            status.nodeManagedByContract = nodeOwner == target || _isWrappedNodeManagedByTarget(nameWrapper, nodeOwner, authoritativeNode, target);
            status.resolverSetToExpected = nodeResolver == pages.publicResolver();

            if (nodeResolver != address(0)) {
                status.schemaTextPresent = _safeHasText(nodeResolver, authoritativeNode, "schema");
                status.specTextPresent = _safeHasText(nodeResolver, authoritativeNode, "agijobs.spec.public");
                status.completionTextPresent = _safeHasText(nodeResolver, authoritativeNode, "agijobs.completion.public");
                status.metadataComplete = status.schemaTextPresent && status.specTextPresent;
                (bool authReadSupported, bool employerKnown, bool employerOk) =
                    employer == address(0) ? (true, true, true) : _safeReadAuthorisation(ens, nameWrapper, nodeResolver, authoritativeNode, employer);
                (bool agentReadSupported, bool agentKnown, bool agentOk) =
                    agent == address(0) ? (true, true, true) : _safeReadAuthorisation(ens, nameWrapper, nodeResolver, authoritativeNode, agent);
                status.authReadSupported = authReadSupported && agentReadSupported;
                status.employerAuthorisedObserved = employerKnown && employerOk;
                status.agentAuthorisedObserved = agentKnown && agentOk;
                status.authObservationIncomplete = (employer != address(0) && !employerKnown) || (agent != address(0) && !agentKnown);
                status.authorisationsAsExpected = !status.authObservationIncomplete && employerOk && agentOk;
            }
        }

        status.finalizable = status.authoritySnapshotted && status.nodeExists && status.resolverSetToExpected;
    }


    function _managerCompatibility(address manager, uint256 jobId)
        internal
        view
        returns (bool managerSupportsV1Views, uint8 managerMode, bool metadataAutoWriteSupported, bool keeperRequired)
    {
        if (manager == address(0) || manager.code.length == 0) {
            return (false, MANAGER_MODE_NONE, false, true);
        }

        (bool ok, bytes memory data) = manager.staticcall(abi.encodeWithSignature('ensJobManagerViewInterfaceVersion()'));
        if (ok && data.length >= 32 && abi.decode(data, (uint256)) == 1) {
            return (true, MANAGER_MODE_RICH, true, false);
        }

        bool coreReadable = _surfaceReadable(manager, abi.encodeWithSignature('getJobCore(uint256)', jobId));
        bool specReadable = _surfaceReadable(manager, abi.encodeWithSignature('getJobSpecURI(uint256)', jobId));
        bool completionReadable = _surfaceReadable(manager, abi.encodeWithSignature('getJobCompletionURI(uint256)', jobId));
        managerSupportsV1Views = coreReadable && specReadable && completionReadable;
        managerMode = managerSupportsV1Views ? MANAGER_MODE_RICH : MANAGER_MODE_LEAN;
        metadataAutoWriteSupported = managerSupportsV1Views;
        keeperRequired = !managerSupportsV1Views;
    }

    function _surfaceReadable(address target, bytes memory payload) internal view returns (bool) {
        if (target == address(0) || target.code.length == 0) return false;
        (bool success, bytes memory data) = target.staticcall(payload);
        return success || data.length != 0;
    }


    function _resolveAuthOwner(address nameWrapper, address nodeOwner, bytes32 node) internal view returns (address authOwner) {
        authOwner = nodeOwner;
        if (nodeOwner == address(0) || nameWrapper == address(0) || nodeOwner != nameWrapper) return authOwner;
        (bool success, bytes memory data) = nameWrapper.staticcall(abi.encodeWithSelector(INameWrapperLite.ownerOf.selector, uint256(node)));
        if (success && data.length >= 32) {
            address wrappedOwner = abi.decode(data, (address));
            if (wrappedOwner != address(0)) return wrappedOwner;
        }
    }

    function _isWrappedNodeManagedByTarget(address nameWrapper, address nodeOwner, bytes32 node, address target) internal view returns (bool) {
        if (nameWrapper == address(0) || nodeOwner != nameWrapper) return false;
        (bool success, bytes memory data) = nameWrapper.staticcall(abi.encodeWithSelector(INameWrapperLite.ownerOf.selector, uint256(node)));
        return success && data.length >= 32 && abi.decode(data, (address)) == target;
    }

    function _safeHasText(address resolver, bytes32 node, string memory key) internal view returns (bool) {
        (bool success, bytes memory data) = resolver.staticcall(abi.encodeWithSignature("text(bytes32,string)", node, key));
        if (!success || data.length == 0) return false;
        return bytes(abi.decode(data, (string))).length != 0;
    }

    function _safeReadAuthorisation(IENSRegistryLite ens, address nameWrapper, address resolver, bytes32 node, address target)
        internal
        view
        returns (bool readSupported, bool known, bool authorised)
    {
        address nodeOwner = ens.owner(node);
        address authOwner = _resolveAuthOwner(nameWrapper, nodeOwner, node);
        bool success;
        bytes memory data;
        (success, data) = resolver.staticcall(abi.encodeWithSignature('authorisations(bytes32,address,address)', node, authOwner, target));
        if (success && data.length >= 32) return (true, true, abi.decode(data, (bool)));

        (success, data) = resolver.staticcall(abi.encodeWithSignature('isApprovedFor(address,bytes32,address)', authOwner, node, target));
        if (success && data.length >= 32) return (true, true, abi.decode(data, (bool)));

        (success, data) = resolver.staticcall(abi.encodeWithSignature('isApprovedForAll(address,address)', authOwner, target));
        if (success && data.length >= 32) return (true, true, abi.decode(data, (bool)));

        (success, data) = resolver.staticcall(abi.encodeWithSignature('isAuthorised(bytes32,address)', node, target));
        if (success && data.length >= 32) return (true, true, abi.decode(data, (bool)));

        return (false, false, false);
    }
}
