// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../ens/IENSJobPagesHooksV1.sol";

contract MockENSJobPages is ERC165, IENSJobPagesHooksV1 {
    using Strings for uint256;

    uint8 public constant HOOK_CREATE = 1;
    uint8 public constant HOOK_ASSIGN = 2;
    uint8 public constant HOOK_COMPLETION = 3;
    uint8 public constant HOOK_REVOKE = 4;
    uint8 public constant HOOK_LOCK = 5;
    uint8 public constant HOOK_LOCK_BURN = 6;

    mapping(uint8 => bool) public revertHook;
    bool public useEnsJobTokenURI;
    bool public useJobEnsUriOverride;
    string public jobEnsUriOverride;
    bool public issued = true;

    uint256 public createCalls;
    uint256 public assignCalls;
    uint256 public completionCalls;
    uint256 public revokeCalls;
    uint256 public lockCalls;

    uint256 public lastJobId;
    address public lastEmployer;
    address public lastAgent;
    string public lastSpecURI;
    string public lastCompletionURI;
    bool public lastBurnFuses;

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IENSJobPagesHooksV1).interfaceId || super.supportsInterface(interfaceId);
    }

    function setRevertHook(uint8 hook, bool shouldRevert) external { revertHook[hook] = shouldRevert; }
    function setIssued(bool value) external { issued = value; }

    function onJobCreated(uint256 jobId, address employer, string calldata specURI) external {
        if (revertHook[HOOK_CREATE]) revert("revert create");
        createCalls += 1; lastJobId = jobId; lastEmployer = employer; lastSpecURI = specURI;
    }
    function onJobAssigned(uint256 jobId, address employer, address agent) external {
        if (revertHook[HOOK_ASSIGN]) revert("revert assign");
        assignCalls += 1; lastJobId = jobId; lastEmployer = employer; lastAgent = agent;
    }
    function onJobCompletionRequested(uint256 jobId, string calldata completionURI) external {
        if (revertHook[HOOK_COMPLETION]) revert("revert completion");
        completionCalls += 1; lastJobId = jobId; lastCompletionURI = completionURI;
    }
    function onJobRevoked(uint256 jobId, address employer, address agent) external {
        if (revertHook[HOOK_REVOKE]) revert("revert revoke");
        revokeCalls += 1; lastJobId = jobId; lastEmployer = employer; lastAgent = agent;
    }
    function onJobLocked(uint256 jobId, address employer, address agent, bool burnFuses) external {
        if (revertHook[HOOK_LOCK]) revert("revert lock");
        lockCalls += 1; lastJobId = jobId; lastEmployer = employer; lastAgent = agent; lastBurnFuses = burnFuses;
    }

    function jobEnsName(uint256 jobId) external pure returns (string memory) {
        return string(abi.encodePacked("agijob-", jobId.toString(), ".alpha.jobs.agi.eth"));
    }
    function jobEnsURI(uint256 jobId) external view returns (string memory) {
        if (useJobEnsUriOverride) return jobEnsUriOverride;
        return string(abi.encodePacked("ens://agijob-", jobId.toString(), ".alpha.jobs.agi.eth"));
    }
    function jobEnsIssued(uint256) external view returns (bool) { return issued; }
    function setJobEnsUriOverride(string calldata uri) external { useJobEnsUriOverride = true; jobEnsUriOverride = uri; }
    function clearJobEnsUriOverride() external { useJobEnsUriOverride = false; jobEnsUriOverride = ""; }
    function setUseEnsJobTokenURI(bool enabled) external { useEnsJobTokenURI = enabled; }
}
