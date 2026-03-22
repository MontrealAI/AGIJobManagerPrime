// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../ens/IENSJobPagesHooksV1.sol";

contract MockENSJobPagesMalformed is ERC165, IENSJobPagesHooksV1 {
    bytes private tokenURIBytes;
    bool public revertOnHook;
    bool public issued = true;

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IENSJobPagesHooksV1).interfaceId || super.supportsInterface(interfaceId);
    }

    function setTokenURIBytes(bytes calldata data) external {
        tokenURIBytes = data;
    }

    function setRevertOnHook(bool shouldRevert) external {
        revertOnHook = shouldRevert;
    }

    function setIssued(bool value) external {
        issued = value;
    }

    function handleHook(uint8, uint256) external view {
        if (revertOnHook) revert();
    }

    function onJobCreated(uint256, address, string calldata) external view { if (revertOnHook) revert(); }
    function onJobAssigned(uint256, address, address) external view { if (revertOnHook) revert(); }
    function onJobCompletionRequested(uint256, string calldata) external view { if (revertOnHook) revert(); }
    function onJobRevoked(uint256, address, address) external view { if (revertOnHook) revert(); }
    function onJobLocked(uint256, address, address, bool) external view { if (revertOnHook) revert(); }

    function jobEnsIssued(uint256) external view returns (bool) { return issued; }

    function jobEnsURI(uint256) external view returns (string memory) {
        bytes memory data = tokenURIBytes;
        assembly {
            return(add(data, 32), mload(data))
        }
    }
}
