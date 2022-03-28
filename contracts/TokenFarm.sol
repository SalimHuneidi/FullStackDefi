// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    address[] public allowedTokens;
    address[] public stakers;

    //mapping token adress -> stakeradress -> amount
    mapping(address => mapping(address => uint256)) public stakingBalance;
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenPriceFeedMapping;
    IERC20 public dappToken;

    constructor(address _dappTokenAddress) {
        dappToken = IERC20(_dappTokenAddress);
    }

    // stake token (DONE)
    function stakeTokens(uint256 _amount, address _token) public {
        require(_amount > 0, "Amount has to be greater than 0! ");
        require(tokenIsAllowed(_token), "Sorry we don't take those tokens yet");

        //tranfer from ERC20 (Transfer only from wallet who owns tokens TransferFrom works by letting the user approve on their wallet)
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensState(msg.sender, _token);
        stakingBalance[_token][msg.sender] =
            stakingBalance[_token][msg.sender] +
            _amount;
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;
    }

    function updateUniqueTokensState(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        for (
            uint256 allowedTokensIdx = 0;
            allowedTokensIdx < allowedTokens.length;
            allowedTokensIdx++
        ) {
            if (allowedTokens[allowedTokensIdx] == _token) {
                return true;
            }
        }
        return false;
    }

    // UnStake Tokens
    // Issue Token
    function issueToken() public onlyOwner {
        //Issue tokens to all stakers
        for (
            uint256 stakerIndex = 0;
            stakerIndex < stakers.length;
            stakerIndex++
        ) {
            address recepient = stakers[stakerIndex];
            //send them a token/reward based on their total value locked.
            uint256 userTotalValue = getUserTotalValue(recepient);
            dappToken.transfer(recepient, userTotalValue);
        }
    }

    function getUserTotalValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        require(uniqueTokensStaked[_user] > 0, "No tokens Staked");
        for (
            uint256 allowedTokensidx;
            allowedTokensidx > allowedTokens.length;
            allowedTokensidx++
        ) {
            totalValue =
                totalValue +
                getUserSingleValue(_user, allowedTokens[allowedTokensidx]);
        }
        return totalValue;
    }

    function getUserSingleValue(address _user, address _token)
        public
        view
        returns (uint256)
    {
        // 1 ETH --> 2000$
        // 1 DAI --> 200$
        if (uniqueTokensStaked[_user] <= 0) {
            return 0;
        }
        (uint256 price, uint256 decimals) = getTokenValue(_token);

        return (stakingBalance[_token][_user] * price) / (10**decimals);
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 Price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = priceFeed.decimals();

        return (uint256(Price), decimals);
    }

    function setTokenValue(address _token, address _priceFeed)
        public
        onlyOwner
        returns (uint256)
    {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }
    // add allowed token
    //getEthValue
}
