// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FroyoTracker} from "../src/FroyoTracker.sol";
import {FroyoToken} from "../src/FroyoToken.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract FroyoTrackerTest is Test {
    
    FroyoTracker public froyoTracker;

    //basic mock users
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        froyoTracker = new FroyoTracker();
    }

    function testPostRestaurant() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("Yogurtland", "123 Main St, Los Angeles, CA"); //Addresses will likely need to be in a standard format
        
        assertEq(restaurantId, 1);
        assertEq(froyoTracker.restaurantCount(), 1);
        
        FroyoTracker.Restaurant memory restaurant = froyoTracker.getRestaurant(1);
        assertEq(restaurant.name, "Yogurtland");
        assertEq(restaurant.location, "123 Main St, Los Angeles, CA");
        assertEq(restaurant.poster, user1);
        assertTrue(restaurant.active);
        assertTrue(restaurant.tokenAddress != address(0));
        
        FroyoToken token = FroyoToken(restaurant.tokenAddress);
        assertEq(token.name(), "Froyo Yogurtland");
        assertEq(token.symbol(), "FYog");
        assertEq(token.balanceOf(user1), froyoTracker.INITIAL_TOKEN_SUPPLY());
    }

    function testReportPrice() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("Pinkberry", "456 Oak Ave, San Francisco, CA");
        
        FroyoTracker.Restaurant memory restaurant = froyoTracker.getRestaurant(restaurantId);
        FroyoToken token = FroyoToken(restaurant.tokenAddress);
        
        vm.prank(user2);
        froyoTracker.reportPrice(restaurantId, 599, "per ounce");
        
        FroyoTracker.PriceReport[] memory reports = froyoTracker.getPriceReports(restaurantId);
        assertEq(reports.length, 1);
        assertEq(reports[0].price, 599);
        assertEq(reports[0].priceType, "per ounce");
        assertEq(reports[0].reporter, user2);
        
        assertEq(token.balanceOf(user2), froyoTracker.REPORTER_REWARD());
    }

    function testMultiplePriceReports() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("16 Handles", "789 Pine St, New York, NY");
        
        FroyoTracker.Restaurant memory restaurant = froyoTracker.getRestaurant(restaurantId);
        FroyoToken token = FroyoToken(restaurant.tokenAddress);
        
        vm.prank(user1);
        froyoTracker.reportPrice(restaurantId, 650, "per ounce");
        
        vm.prank(user2);
        froyoTracker.reportPrice(restaurantId, 700, "per ounce");
        
        FroyoTracker.PriceReport[] memory reports = froyoTracker.getPriceReports(restaurantId);
        assertEq(reports.length, 2);
        assertEq(reports[0].price, 650);
        assertEq(reports[1].price, 700);
        
        assertEq(token.balanceOf(user1), froyoTracker.INITIAL_TOKEN_SUPPLY() + froyoTracker.REPORTER_REWARD());
        assertEq(token.balanceOf(user2), froyoTracker.REPORTER_REWARD());
    }

    function testGetLatestPrice() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("Menchie's", "321 Elm St, Chicago, IL");
        
        FroyoTracker.Restaurant memory restaurant = froyoTracker.getRestaurant(restaurantId);
        FroyoToken token = FroyoToken(restaurant.tokenAddress);
        
        vm.prank(user1);
        froyoTracker.reportPrice(restaurantId, 550, "per ounce");
        
        vm.warp(block.timestamp + 1 hours);
        
        vm.prank(user2);
        froyoTracker.reportPrice(restaurantId, 600, "per ounce");
        
        (uint256 price, string memory priceType, address reporter, uint256 timestamp) = froyoTracker.getLatestPrice(restaurantId);
        assertEq(price, 600);
        assertEq(priceType, "per ounce");
        assertEq(reporter, user2);
        assertEq(timestamp, block.timestamp);
        
        assertEq(token.balanceOf(user1), froyoTracker.INITIAL_TOKEN_SUPPLY() + froyoTracker.REPORTER_REWARD());
        assertEq(token.balanceOf(user2), froyoTracker.REPORTER_REWARD());
    }

    function testDeactivateRestaurant() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("Red Mango", "999 Broadway, Seattle, WA");
        
        vm.prank(user1);
        froyoTracker.deactivateRestaurant(restaurantId);
        
        FroyoTracker.Restaurant memory restaurant = froyoTracker.getRestaurant(restaurantId);
        assertFalse(restaurant.active);
    }

    function test_RevertWhen_DeactivateRestaurantNotOwner() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("TCBY", "555 Market St, Austin, TX");
        
        vm.prank(user2);
        vm.expectRevert("Only poster can deactivate");
        froyoTracker.deactivateRestaurant(restaurantId);
    }

    function test_RevertWhen_ReportPriceInvalidRestaurant() public {
        vm.prank(user1);
        vm.expectRevert("Invalid restaurant ID");
        froyoTracker.reportPrice(999, 500, "per ounce");
    }

    function test_RevertWhen_ReportPriceZeroPrice() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("Orange Leaf", "777 State St, Denver, CO");
        
        vm.prank(user2);
        vm.expectRevert("Price must be greater than 0");
        froyoTracker.reportPrice(restaurantId, 0, "per ounce");
    }

    function test_RevertWhen_ReportPriceInactiveRestaurant() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("Tutti Frutti", "888 Main St, Portland, OR");
        
        vm.prank(user1);
        froyoTracker.deactivateRestaurant(restaurantId);
        
        vm.prank(user2);
        vm.expectRevert("Restaurant is not active");
        froyoTracker.reportPrice(restaurantId, 600, "per ounce");
    }

    function testTokenCreation() public {
        vm.startPrank(user1);
        
        uint256 id1 = froyoTracker.postRestaurant("Yogurtland", "123 Main St");
        uint256 id2 = froyoTracker.postRestaurant("A", "456 Oak Ave");
        uint256 id3 = froyoTracker.postRestaurant("Very Long Restaurant Name", "789 Pine St");
        
        FroyoTracker.Restaurant memory r1 = froyoTracker.getRestaurant(id1);
        FroyoTracker.Restaurant memory r2 = froyoTracker.getRestaurant(id2);
        FroyoTracker.Restaurant memory r3 = froyoTracker.getRestaurant(id3);
        
        FroyoToken token1 = FroyoToken(r1.tokenAddress);
        FroyoToken token2 = FroyoToken(r2.tokenAddress);
        FroyoToken token3 = FroyoToken(r3.tokenAddress);
        
        assertEq(token1.symbol(), "FYog");
        assertEq(token2.symbol(), "FA");
        assertEq(token3.symbol(), "FVer");
        
        vm.stopPrank();
    }

    function testTokenTransfer() public {
        vm.prank(user1);
        uint256 restaurantId = froyoTracker.postRestaurant("Sweet Frog", "123 Market St");
        
        FroyoTracker.Restaurant memory restaurant = froyoTracker.getRestaurant(restaurantId);
        FroyoToken token = FroyoToken(restaurant.tokenAddress);
        
        uint256 transferAmount = 1000 * 10**18;
        
        vm.prank(user1);
        token.transfer(user2, transferAmount);
        
        assertEq(token.balanceOf(user1), froyoTracker.INITIAL_TOKEN_SUPPLY() - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }
}