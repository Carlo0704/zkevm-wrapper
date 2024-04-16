// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ZkEVMWrapper} from "src/ZkEVMWrapper.sol";
import {IZkEVMBridge} from "src/interfaces/IZkEVMBridge.sol";

contract ZkEVMWrapperDeploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ZkEVMWrapper
        ZkEVMWrapper wrapper = new ZkEVMWrapper(
            IZkEVMBridge(0x528e26b25a34a4A5d0dbDa1d57D318153d2ED582)
        );

        vm.stopBroadcast();
    }
}
