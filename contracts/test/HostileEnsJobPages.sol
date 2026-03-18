// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract HostileEnsJobPages {
    enum Mode {
        Noop,
        RevertAlways,
        BurnGas,
        ReturnGarbage
    }

    Mode public mode;
    uint256 public spinCount = 200;
    uint256 public hookCalls;

    function setMode(Mode next) external {
        mode = next;
    }

    function setSpinCount(uint256 next) external {
        spinCount = next;
    }

    function handleHook(uint8, uint256) external {
        hookCalls += 1;
        if (mode == Mode.RevertAlways) revert("hostile-hook");
        if (mode == Mode.BurnGas) {
            uint256 acc;
            for (uint256 i = 0; i < spinCount; ++i) {
                acc += i;
            }
            if (acc == type(uint256).max) revert();
        }
    }

    function jobEnsURI(uint256) external view returns (string memory) {
        if (mode == Mode.ReturnGarbage) {
            bytes memory data = hex"123456";
            assembly {
                return(add(data, 0x20), mload(data))
            }
        }
        return "ens://hostile";
    }
}
