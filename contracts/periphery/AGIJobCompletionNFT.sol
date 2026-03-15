// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AGIJobCompletionNFT is ERC721 {
    error NotManager();

    address public immutable manager;
    uint256 public nextTokenId;
    mapping(uint256 => string) private _tokenURIs;

    constructor(address manager_) ERC721("AGIJobs Prime", "AGIJP") {
        manager = manager_;
    }

    function mintCompletion(address to, string calldata uri) external returns (uint256 tokenId) {
        if (msg.sender != manager) revert NotManager();
        tokenId = nextTokenId++;
        _tokenURIs[tokenId] = uri;
        _mint(to, tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        return _tokenURIs[tokenId];
    }
}
