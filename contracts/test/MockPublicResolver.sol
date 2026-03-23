// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockPublicResolver {
    mapping(bytes32 => mapping(address => bool)) private authStatus;
    mapping(bytes32 => mapping(bytes32 => string)) private textRecords;

    bool public revertSetAuthorisation;
    bool public revertSetText;

    function setRevertSetAuthorisation(bool shouldRevert) external {
        revertSetAuthorisation = shouldRevert;
    }

    function setRevertSetText(bool shouldRevert) external {
        revertSetText = shouldRevert;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x59d1d43c ||
            interfaceId == 0x10f13a8c ||
            interfaceId == 0x304e6ade;
    }

    function setAuthorisation(bytes32 node, address target, bool authorised) external {
        if (revertSetAuthorisation) revert();
        authStatus[node][target] = authorised;
    }

    function isAuthorised(bytes32 node, address target) external view returns (bool) {
        return authStatus[node][target];
    }

    function authorisations(bytes32 node, address owner, address target) external view returns (bool) {
        owner;
        return authStatus[node][target];
    }

    function setText(bytes32 node, string calldata key, string calldata value) external {
        if (revertSetText) revert();
        textRecords[node][keccak256(bytes(key))] = value;
    }

    function text(bytes32 node, string calldata key) external view returns (string memory) {
        return textRecords[node][keccak256(bytes(key))];
    }
}
