// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FroyoToken} from "./FroyoToken.sol";

contract FroyoTracker {
    struct Restaurant {
        string name;
        string location;
        address poster;
        uint256 timestamp;
        bool active;
        address tokenAddress;
    }

    struct PriceReport {
        address reporter;
        uint256 price;
        uint256 timestamp;
        string priceType;
    }

    mapping(uint256 => Restaurant) public restaurants;
    mapping(uint256 => PriceReport[]) public priceReports;
    
    uint256 public restaurantCount;
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000000 * 10**18;
    uint256 public constant REPORTER_REWARD = 100 * 10**18;
    
    //Events should be used to help website with state, will need to actally remember to use them
    event RestaurantPosted(uint256 indexed restaurantId, string name, string location, address poster, address tokenAddress);
    event PriceReported(uint256 indexed restaurantId, uint256 price, string priceType, address reporter);
    
    function postRestaurant(string memory _name, string memory _location) public returns (uint256) {
        restaurantCount++;
        
        string memory tokenName = string(abi.encodePacked("Froyo ", _name));
        string memory tokenSymbol = string(abi.encodePacked("F", _createSymbol(_name)));
        
        FroyoToken token = new FroyoToken(tokenName, tokenSymbol, address(this));
        
        restaurants[restaurantCount] = Restaurant({
            name: _name,
            location: _location,
            poster: msg.sender,
            timestamp: block.timestamp,
            active: true,
            tokenAddress: address(token)
        });
        
        token.mint(msg.sender, INITIAL_TOKEN_SUPPLY);
        
        emit RestaurantPosted(restaurantCount, _name, _location, msg.sender, address(token));
        
        return restaurantCount;
    }
    
    function reportPrice(uint256 _restaurantId, uint256 _price, string memory _priceType) public {
        require(_restaurantId > 0 && _restaurantId <= restaurantCount, "Invalid restaurant ID");
        require(restaurants[_restaurantId].active, "Restaurant is not active");
        require(_price > 0, "Price must be greater than 0");
        
        priceReports[_restaurantId].push(PriceReport({
            reporter: msg.sender,
            price: _price,
            timestamp: block.timestamp,
            priceType: _priceType
        }));
        
        FroyoToken(restaurants[_restaurantId].tokenAddress).mint(msg.sender, REPORTER_REWARD);
        
        emit PriceReported(_restaurantId, _price, _priceType, msg.sender);
    }
    
    function getRestaurant(uint256 _restaurantId) public view returns (Restaurant memory) {
        require(_restaurantId > 0 && _restaurantId <= restaurantCount, "Invalid restaurant ID");
        return restaurants[_restaurantId];
    }
    
    function getPriceReports(uint256 _restaurantId) public view returns (PriceReport[] memory) {
        require(_restaurantId > 0 && _restaurantId <= restaurantCount, "Invalid restaurant ID");
        return priceReports[_restaurantId];
    }
    
    function getLatestPrice(uint256 _restaurantId) public view returns (uint256, string memory, address, uint256) {
        require(_restaurantId > 0 && _restaurantId <= restaurantCount, "Invalid restaurant ID");
        require(priceReports[_restaurantId].length > 0, "No price reports for this restaurant");
        
        PriceReport memory latest = priceReports[_restaurantId][priceReports[_restaurantId].length - 1];
        return (latest.price, latest.priceType, latest.reporter, latest.timestamp);
    }
    
    function deactivateRestaurant(uint256 _restaurantId) public {
        require(_restaurantId > 0 && _restaurantId <= restaurantCount, "Invalid restaurant ID");
        require(restaurants[_restaurantId].poster == msg.sender, "Only poster can deactivate");
        
        restaurants[_restaurantId].active = false;
    }
    
    function _createSymbol(string memory _name) private pure returns (string memory) {
        bytes memory nameBytes = bytes(_name);
        uint256 length = nameBytes.length > 3 ? 3 : nameBytes.length;
        bytes memory symbolBytes = new bytes(length);
        
        for (uint256 i = 0; i < length; i++) {
            symbolBytes[i] = nameBytes[i];
        }
        
        return string(symbolBytes);
    }
}