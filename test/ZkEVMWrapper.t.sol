// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {MockERC20} from "src/mocks/MockERC20.sol";
import {MockDai} from "src/mocks/MockDai.sol";
import {MockZkEVMBridge} from "src/mocks/MockZkEVMBridge.sol";
import {ZkEVMWrapper} from "src/ZkEVMWrapper.sol";
import {IZkEVMBridge} from "src/interfaces/IZkEVMBridge.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IDai} from "src/interfaces/IDai.sol";
import {SigUtils} from "./SigUtils.t.sol";
import "forge-std/Test.sol";

contract ZkEVMWrapperTest is Test {
    MockERC20 public token;
    MockDai public dai;
    ZkEVMWrapper public wrapper;
    MockZkEVMBridge public bridge;
    SigUtils public sigUtils;

    function setUp() external {
        token = new MockERC20();
        dai = new MockDai(block.chainid);
        sigUtils = new SigUtils(
            IERC20Permit(token).DOMAIN_SEPARATOR(),
            dai.DOMAIN_SEPARATOR()
        );
        bridge = new MockZkEVMBridge();
        wrapper = new ZkEVMWrapper(IZkEVMBridge(address(bridge)));
    }

    function testDeposit(
        address user,
        uint32 destinationNetwork,
        uint256 tokenAmount,
        uint256 etherAmount,
        address destination
    ) external payable {
        vm.assume(user != address(0) && etherAmount != 0);
        vm.deal(user, etherAmount);
        token.mint(user, tokenAmount);
        vm.startPrank(user);
        token.approve(address(wrapper), tokenAmount);
        wrapper.deposit{value: etherAmount}(
            IERC20(token),
            destinationNetwork,
            destination,
            tokenAmount
        );
        assertEq(token.balanceOf(address(bridge)), tokenAmount);
        assertEq(address(bridge).balance, etherAmount);
    }

    function testDepositPermit(
        uint256 privKey,
        uint256 tokenAmount,
        uint256 etherAmount,
        uint32 destinationNetwork,
        address destination,
        uint256 deadline
    ) external payable {
        // privkey value must be lower than secp256k1 curve order
        vm.assume(
            privKey != 0 &&
                privKey <
                115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        address user = vm.addr(privKey);
        vm.assume(user != address(0) && deadline > 0 && etherAmount != 0);
        vm.deal(user, etherAmount);
        token.mint(user, tokenAmount);
        vm.startPrank(user);
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: user,
            spender: address(wrapper),
            value: tokenAmount,
            nonce: 0,
            deadline: deadline
        });
        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        wrapper.deposit{value: etherAmount}(
            IERC20(token),
            destinationNetwork,
            destination,
            tokenAmount,
            deadline,
            v,
            r,
            s
        );
        assertEq(token.balanceOf(address(bridge)), tokenAmount);
        assertEq(address(bridge).balance, etherAmount);
    }

    function testDepositDaiPermit(
        uint256 privKey,
        uint256 tokenAmount,
        uint256 etherAmount,
        uint32 destinationNetwork,
        address destination,
        uint256 expiry
    ) external payable {
        // privkey value must be lower than secp256k1 curve order
        vm.assume(
            privKey != 0 &&
                privKey <
                115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        address user = vm.addr(privKey);
        vm.assume(user != address(0) && expiry > 0 && etherAmount != 0);
        vm.deal(user, etherAmount);
        dai.mint(user, tokenAmount);
        vm.startPrank(user);
        SigUtils.DaiPermit memory permit = SigUtils.DaiPermit({
            holder: user,
            spender: address(wrapper),
            nonce: 0,
            expiry: expiry,
            allowed: true
        });
        bytes32 digest = sigUtils.getDaiTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        wrapper.deposit{value: etherAmount}(
            IDai(address(dai)),
            tokenAmount,
            destinationNetwork,
            destination,
            0,
            expiry,
            true,
            v,
            r,
            s
        );
        assertEq(dai.balanceOf(address(bridge)), tokenAmount);
        assertEq(address(bridge).balance, etherAmount);
    }
}
