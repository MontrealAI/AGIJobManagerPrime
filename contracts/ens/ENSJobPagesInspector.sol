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
    function jobAuthorityInfo(uint256 jobId) external view returns (bool,string memory,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool);
    function rootVersionCount() external view returns (uint256);
    function currentRootVersionId() external view returns (uint256);
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
        uint8 repairRecommendationCode;
        uint256 rootVersionCount;
        uint256 currentRootVersionId;
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
        uint256 failureBitmap;
        bool configurationReadable;
        try pages.validateConfiguration() returns (uint256 failureBitmap_) {
            failureBitmap = failureBitmap_;
            configurationReadable = true;
        } catch {}

        bool locked = _safeBoolCall(target, abi.encodeWithSignature("configLocked()"));
        bytes32 jobsRootNode = _safeBytes32Call(target, abi.encodeWithSignature("jobsRootNode()"));
        string memory jobsRootName = _safeStringCall(target, abi.encodeWithSignature("jobsRootName()"));
        bool rootConfigured = jobsRootNode != bytes32(0) && bytes(jobsRootName).length != 0;
        bool rootNodeMatchesRootName = rootConfigured && _namehash(jobsRootName) == jobsRootNode;
        bool rootNormalized = rootConfigured && _isValidRootName(jobsRootName);
        address ensAddress = pages.ens();
        address resolverAddressExpected = pages.publicResolver();
        address nameWrapperAddress = pages.nameWrapper();
        address rootOwner = jobsRootNode == bytes32(0) ? address(0) : IENSRegistryLite(ensAddress).owner(jobsRootNode);
        bool wrappedRoot = rootOwner == nameWrapperAddress && nameWrapperAddress != address(0);
        bool wrapperAuthorizationReady = wrappedRoot && _isWrapperAuthorizationReady(nameWrapperAddress, jobsRootNode, target);
        bool resolverSupportsText = configurationReadable && (failureBitmap & (1 << 7)) == 0;
        bool resolverSupportsSetText = configurationReadable && (failureBitmap & (1 << 8)) == 0;
        bool resolverSupportsAuthorisation = configurationReadable && (failureBitmap & (1 << 9)) == 0;
        bool configured = configurationReadable && failureBitmap == 0;

        bool authorityEstablished;
        string memory label;
        bytes32 authoritativeRootNode;
        bytes32 authoritativeNode;
        bool legacyImported;
        bool finalized;
        bool fuseBurned;
        try pages.jobAuthorityInfo(jobId) returns (
            bool authorityEstablished_,
            string memory label_,
            bytes32,
            uint32,
            bytes32 authoritativeRootNode_,
            bytes32 authoritativeNode_,
            uint8,
            uint32,
            uint64,
            bool legacyImported_,
            bool finalized_,
            bool fuseBurned_
        ) {
            authorityEstablished = authorityEstablished_;
            label = label_;
            authoritativeRootNode = authoritativeRootNode_;
            authoritativeNode = authoritativeNode_;
            legacyImported = legacyImported_;
            finalized = finalized_;
            fuseBurned = fuseBurned_;
        } catch {}

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
        status.previewLabel = _safeStringCall(target, abi.encodeWithSignature("previewJobEnsLabel(uint256)", jobId));
        status.previewName = _safeStringCall(target, abi.encodeWithSignature("previewJobEnsName(uint256)", jobId));
        status.previewURI = _safeStringCall(target, abi.encodeWithSignature("previewJobEnsURI(uint256)", jobId));
        status.previewReady = bytes(status.previewName).length != 0;
        status.failureCode = configurationReadable ? failureBitmap : type(uint256).max;
        status.rootVersionCount = _safeUintCall(target, abi.encodeWithSignature("rootVersionCount()"));
        status.currentRootVersionId = _safeUintCall(target, abi.encodeWithSignature("currentRootVersionId()"));

        if (authorityEstablished) {
            status.effectiveLabel = _safeStringCall(target, abi.encodeWithSignature("effectiveJobEnsLabel(uint256)", jobId));
            status.effectiveName = _safeStringCall(target, abi.encodeWithSignature("effectiveJobEnsName(uint256)", jobId));
            status.effectiveURI = _safeStringCall(target, abi.encodeWithSignature("effectiveJobEnsURI(uint256)", jobId));
            status.effectiveNode = _safeBytes32Call(target, abi.encodeWithSignature("effectiveJobEnsNode(uint256)", jobId));
            status.effectiveReady = bytes(status.effectiveName).length != 0;

            IENSRegistryLite ens = IENSRegistryLite(ensAddress);
            address nameWrapper = nameWrapperAddress;
            address nodeOwner = ens.owner(authoritativeNode);
            address nodeResolver = ens.resolver(authoritativeNode);
            status.nodeExists = nodeOwner != address(0);
            status.nodeManagedByContract = nodeOwner == target || _isWrappedNodeManagedByTarget(nameWrapper, nodeOwner, authoritativeNode, target);
            status.resolverSetToExpected = nodeResolver == resolverAddressExpected;

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
        status.repairRecommendationCode = _repairRecommendation(status);
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
        if (managerSupportsV1Views) {
            return (true, MANAGER_MODE_RICH, true, false);
        }

        bool leanEmployerReadable = _surfaceReadable(manager, abi.encodeWithSignature('jobEmployerOf(uint256)', jobId));
        bool leanAgentReadable = _surfaceReadable(manager, abi.encodeWithSignature('jobAssignedAgentOf(uint256)', jobId));
        if (leanEmployerReadable && leanAgentReadable) {
            return (false, MANAGER_MODE_LEAN, false, true);
        }

        return (false, MANAGER_MODE_NONE, false, true);
    }

    function _surfaceReadable(address target, bytes memory payload) internal view returns (bool) {
        if (target == address(0) || target.code.length == 0) return false;
        (bool success, bytes memory data) = target.staticcall(payload);
        return success || data.length != 0;
    }

    function _safeStringCall(address target, bytes memory payload) internal view returns (string memory value) {
        if (target == address(0) || target.code.length == 0) return "";
        (bool success, bytes memory data) = target.staticcall(payload);
        if (!success || data.length == 0) return "";
        value = abi.decode(data, (string));
    }

    function _safeBytes32Call(address target, bytes memory payload) internal view returns (bytes32 value) {
        if (target == address(0) || target.code.length == 0) return bytes32(0);
        (bool success, bytes memory data) = target.staticcall(payload);
        if (!success || data.length < 32) return bytes32(0);
        value = abi.decode(data, (bytes32));
    }



    function _safeBoolCall(address target, bytes memory payload) internal view returns (bool value) {
        if (target == address(0) || target.code.length == 0) return false;
        (bool success, bytes memory data) = target.staticcall(payload);
        if (!success || data.length < 32) return false;
        uint256 decoded = abi.decode(data, (uint256));
        if (decoded > 1) return false;
        return decoded != 0;
    }

    function _safeUintCall(address target, bytes memory payload) internal view returns (uint256 value) {
        if (target == address(0) || target.code.length == 0) return 0;
        (bool success, bytes memory data) = target.staticcall(payload);
        if (!success || data.length < 32) return 0;
        return abi.decode(data, (uint256));
    }

    function _repairRecommendation(JobStatusView memory status) internal pure returns (uint8) {
        if (!status.authoritySnapshotted) {
            if (!status.labelSnapshotted) return 1; // import exact label first
            if (status.rootVersionCount > 1) return 2; // explicit root version repair required
            return 3; // single-root authority repair
        }
        if (!status.nodeExists) return 4; // create/adopt node
        if (!status.nodeManagedByContract) return 5; // adoption needed
        if (!status.resolverSetToExpected) return 6; // resolver repair
        if (!status.metadataComplete) return 7; // metadata hydration
        if (!status.authorisationsAsExpected && !status.authObservationIncomplete) return 8; // auth repair
        if (status.authObservationIncomplete) return 9; // observation incomplete
        return 0; // no action
    }

    function _isWrapperAuthorizationReady(address nameWrapper, bytes32 rootNode, address target) internal view returns (bool) {
        if (nameWrapper == address(0) || rootNode == bytes32(0)) return false;
        (bool success, bytes memory data) = nameWrapper.staticcall(abi.encodeWithSelector(INameWrapperLite.ownerOf.selector, uint256(rootNode)));
        if (!success || data.length < 32) return false;
        address wrappedOwner = abi.decode(data, (address));
        if (wrappedOwner == address(0)) return false;
        if (wrappedOwner == target) return true;
        (success, data) = nameWrapper.staticcall(abi.encodeWithSignature("getApproved(uint256)", uint256(rootNode)));
        if (success && data.length >= 32 && abi.decode(data, (address)) == target) return true;
        (success, data) = nameWrapper.staticcall(abi.encodeWithSignature("isApprovedForAll(address,address)", wrappedOwner, target));
        return success && data.length >= 32 && abi.decode(data, (bool));
    }

    function _isValidRootName(string memory rootName) internal pure returns (bool) {
        bytes memory raw = bytes(rootName);
        uint256 len = raw.length;
        if (len == 0 || len > 240) return false;
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

        (success, data) = resolver.staticcall(abi.encodeWithSignature('isApprovedFor(bytes32,address)', node, target));
        if (success && data.length >= 32) return (true, true, abi.decode(data, (bool)));

        (success, data) = resolver.staticcall(abi.encodeWithSignature('isApprovedForAll(address,address)', authOwner, target));
        if (success && data.length >= 32) return (true, true, abi.decode(data, (bool)));

        return (false, false, false);
    }
}
