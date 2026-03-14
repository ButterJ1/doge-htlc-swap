// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { EscrowFactory } from "../contracts/EscrowFactory.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console2.log("Deployer  :", deployer);
        console2.log("Chain ID  :", block.chainid);
        console2.log("Balance   :", deployer.balance);

        vm.startBroadcast(deployerKey);

        EscrowFactory factory = new EscrowFactory();

        console2.log("EscrowFactory :", address(factory));
        console2.log("EscrowSrc impl:", factory.escrowSrcImpl());
        console2.log("EscrowDst impl:", factory.escrowDstImpl());

        vm.stopBroadcast();
    }
}
