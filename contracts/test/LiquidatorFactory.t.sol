// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }          from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { Liquidator }            from "../Liquidator.sol";
import { LiquidatorFactory }     from "../LiquidatorFactory.sol";
import { LiquidatorInitializer } from "../LiquidatorInitializer.sol";

import { MockFactory, MockGlobals, MockLoanManager } from "./mocks/Mocks.sol";

contract LiquidatorFactoryTests is TestUtils {

    address internal governor;
    address internal implementation;
    address internal initializer;
    address internal poolDelegate;

    MockERC20       internal collateralAsset;
    MockERC20       internal fundsAsset;
    MockFactory     internal loanManagerFactory;
    MockGlobals     internal globals;
    MockLoanManager internal loanManager;

    LiquidatorFactory internal liquidatorFactory;

    function setUp() external {
        governor     = address(new Address());
        poolDelegate = address(new Address());

        implementation = address(new Liquidator());
        initializer    = address(new LiquidatorInitializer());

        collateralAsset    = new MockERC20("Collateral Asset", "CA", 18);
        fundsAsset         = new MockERC20("Funds Asset",      "FA", 18);
        globals            = new MockGlobals(address(governor));
        loanManagerFactory = new MockFactory();

        loanManager = new MockLoanManager(address(globals), address(fundsAsset), address(poolDelegate));

        vm.startPrank(governor);
        liquidatorFactory = new LiquidatorFactory(address(globals));
        liquidatorFactory.registerImplementation(1, address(implementation), address(initializer));
        liquidatorFactory.setDefaultVersion(1);
        vm.stopPrank();

        globals.__setFactory("LOAN_MANAGER", address(loanManagerFactory), true);
        loanManagerFactory.__setInstance(address(loanManager), true);
        loanManager.__setFactory(address(loanManagerFactory));
    }

    function test_createInstance_invalidLoanManagerFactory() external {
        bytes memory data = abi.encode(address(loanManager), address(collateralAsset), address(fundsAsset));

        loanManager.__setFactory(address(1));

        vm.prank(address(loanManager));
        vm.expectRevert("LF:CI:INVALID_FACTORY");
        liquidatorFactory.createInstance(data, "SALT");

        loanManager.__setFactory(address(loanManagerFactory));

        vm.prank(address(loanManager));
        liquidatorFactory.createInstance(data, "SALT");
    }

    function test_createInstance_invalidLoanManager() external {
        bytes memory data = abi.encode(address(loanManager), address(collateralAsset), address(fundsAsset));

        loanManagerFactory.__setInstance(address(loanManager), false);

        vm.prank(address(loanManager));
        vm.expectRevert("LF:CI:INVALID_INSTANCE");
        liquidatorFactory.createInstance(data, "SALT");

        loanManagerFactory.__setInstance(address(loanManager), true);

        vm.prank(address(loanManager));
        liquidatorFactory.createInstance(data, "SALT");
    }

    function test_createInstance_zeroLoanManager() external {
        bytes memory data = abi.encode(address(0), address(collateralAsset), address(fundsAsset));

        vm.prank(address(loanManager));
        vm.expectRevert("MPF:CI:FAILED");
        liquidatorFactory.createInstance(data, "SALT");

        data = abi.encode(address(loanManager), address(collateralAsset), address(fundsAsset));

        vm.prank(address(loanManager));
        liquidatorFactory.createInstance(data, "SALT");
    }

    function test_createInstance_success() external {
        bytes memory data = abi.encode(address(loanManager), address(collateralAsset), address(fundsAsset));

        vm.prank(address(loanManager));
        Liquidator liquidator = Liquidator(liquidatorFactory.createInstance(data, "SALT"));

        assertEq(liquidator.collateralAsset(), address(collateralAsset));
        assertEq(liquidator.factory(),         address(liquidatorFactory));
        assertEq(liquidator.fundsAsset(),      address(fundsAsset));
        assertEq(liquidator.globals(),         address(globals));
        assertEq(liquidator.governor(),        address(governor));
        assertEq(liquidator.implementation(),  address(implementation));
        assertEq(liquidator.loanManager(),     address(loanManager));
        assertEq(liquidator.poolDelegate(),    address(poolDelegate));
    }

}
