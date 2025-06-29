// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {FroyoTracker} from "../src/FroyoTracker.sol";

contract FroyoTrackerScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        FroyoTracker froyoTracker = new FroyoTracker();
        console.log("FroyoTracker deployed at:", address(froyoTracker));

        vm.stopBroadcast();
    }
}