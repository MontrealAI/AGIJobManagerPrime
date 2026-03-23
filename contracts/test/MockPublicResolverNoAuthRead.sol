// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockPublicResolverNoAuthRead {
    mapping(bytes32 => mapping(bytes32 => string)) private textRecords;
    mapping(bytes32 => mapping(address => bool)) private authorisations;

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x59d1d43c || interfaceId == 0x10f13a8c || interfaceId == 0x304e6ade;
    }

    function setAuthorisation(bytes32 node, address target, bool authorised) external {
        authorisations[node][target] = authorised;
    }

    function setText(bytes32 node, string calldata key, string calldata value) external {
        textRecords[node][keccak256(bytes(key))] = value;
    }

    function text(bytes32 node, string calldata key) external view returns (string memory) {
        return textRecords[node][keccak256(bytes(key))];
    }
}
