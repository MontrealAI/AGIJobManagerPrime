// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockPublicResolverApprove {
    mapping(bytes32 => mapping(bytes32 => string)) private textRecords;
    mapping(bytes32 => mapping(address => bool)) private approvals;
    mapping(address => mapping(address => bool)) private operatorApprovals;

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x59d1d43c || interfaceId == 0x10f13a8c;
    }

    function approve(bytes32 node, address delegate, bool approved) external returns (bool) {
        approvals[node][delegate] = approved;
        return true;
    }

    function isApprovedFor(bytes32 node, address delegate) external view returns (bool) {
        return approvals[node][delegate];
    }

    function setApprovalForAll(address operator, bool approved) external {
        operatorApprovals[msg.sender][operator] = approved;
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return operatorApprovals[owner][operator];
    }

    function setText(bytes32 node, string calldata key, string calldata value) external {
        textRecords[node][keccak256(bytes(key))] = value;
    }

    function text(bytes32 node, string calldata key) external view returns (string memory) {
        return textRecords[node][keccak256(bytes(key))];
    }
}
