// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IENSRegistryMigration {
    function owner(bytes32 node) external view returns (address);
    function setSubnodeRecord(bytes32 node, bytes32 label, address owner, address resolver, uint64 ttl) external;
}

interface INameWrapperMigration {
    function ownerOf(uint256 tokenId) external view returns (address);
    function setSubnodeRecord(
        bytes32 parentNode,
        string calldata label,
        address owner,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32);
}

interface IENSJobPagesMigrationTarget {
    function owner() external view returns (address);
    function ens() external view returns (address);
    function nameWrapper() external view returns (address);
    function repairAuthoritySnapshotExplicit(uint256 jobId, string calldata exactLabel, uint256 rootVersionId) external;
    function jobAuthorityInfo(uint256 jobId)
        external
        view
        returns (bool,string memory,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool);
    function replayCreateExplicit(uint256 jobId, address employer, string calldata specURI) external;
}

contract ENSJobPagesMigrationHelper is Ownable {
    error InvalidParameters();
    error AdoptionBlocked(bytes32 node, address currentOwner);

    event LegacyNodeAdopted(address indexed pages, uint256 indexed jobId, bytes32 indexed node, bool created, bool adopted);

    constructor() {}

    function migrateLegacyJobPageExplicit(
        address pages,
        uint256 jobId,
        string calldata exactLabel,
        uint256 rootVersionId,
        address employer,
        string calldata specURI
    ) external onlyOwner {
        if (pages == address(0) || employer == address(0) || bytes(exactLabel).length == 0 || rootVersionId == 0) revert InvalidParameters();

        IENSJobPagesMigrationTarget target = IENSJobPagesMigrationTarget(pages);
        if (target.owner() != address(this)) revert InvalidParameters();
        target.repairAuthoritySnapshotExplicit(jobId, exactLabel, rootVersionId);
        (, , , , bytes32 rootNode, bytes32 node, , , , , , ) = target.jobAuthorityInfo(jobId);
        if (rootNode == bytes32(0) || node == bytes32(0)) revert InvalidParameters();

        IENSRegistryMigration ensRegistry = IENSRegistryMigration(target.ens());
        address wrapper = target.nameWrapper();
        address currentOwner = ensRegistry.owner(node);
        bool created = false;
        bool adopted = false;

        if (currentOwner == address(0)) {
            target.replayCreateExplicit(jobId, employer, specURI);
            created = true;
        } else if (!_nodeManagedByTarget(wrapper, currentOwner, node, pages)) {
            _adoptNode(ensRegistry, wrapper, rootNode, exactLabel, node, pages);
            adopted = true;
        }

        target.replayCreateExplicit(jobId, employer, specURI);
        emit LegacyNodeAdopted(pages, jobId, node, created, adopted);
    }

    function _adoptNode(
        IENSRegistryMigration ensRegistry,
        address wrapper,
        bytes32 rootNode,
        string calldata label,
        bytes32 node,
        address pages
    ) internal {
        address rootOwner = ensRegistry.owner(rootNode);
        if (rootOwner == wrapper && wrapper != address(0)) {
            INameWrapperMigration(wrapper).setSubnodeRecord(rootNode, label, pages, address(0), 0, 0, type(uint64).max);
        } else if (rootOwner == address(this)) {
            ensRegistry.setSubnodeRecord(rootNode, keccak256(bytes(label)), pages, address(0), 0);
        } else {
            revert AdoptionBlocked(node, ensRegistry.owner(node));
        }
    }

    function _nodeManagedByTarget(address wrapper, address nodeOwner, bytes32 node, address pages) internal view returns (bool) {
        if (nodeOwner == pages) return true;
        if (wrapper == address(0) || nodeOwner != wrapper) return false;
        try INameWrapperMigration(wrapper).ownerOf(uint256(node)) returns (address wrappedOwner) {
            return wrappedOwner == pages;
        } catch {
            return false;
        }
    }
}
