pragma solidity 0.8.4;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YourToken.sol";

contract Vendor is Ownable {

  event BuyTokens(address buyer, uint256 amountOfEth, uint256 amountOfTokens);

  event SellTokens(address seller, uint256 amountOfTokens, uint256 amountOfEth);

  YourToken public yourToken;

  uint256 public constant tokensPerEth = 100;

  constructor(address tokenAddress) {
    yourToken = YourToken(tokenAddress);
  }

  // payable buyTokens() function
  function buyTokens() public payable {
    uint256 amount = msg.value * tokensPerEth;
    require(amount <= yourToken.balanceOf(address(this)), "Not enough GLD available");

    bool transferred = yourToken.transfer(msg.sender, amount);
    require(transferred, "ERC20: Tokens could not be transferred");

    emit BuyTokens(msg.sender, msg.value, amount);
  }

  // lets the owner withdraw ETH
  function withdraw(uint256 amount) public onlyOwner {
    require(amount <= address(this).balance, "Trying to withdraw more than available");

    (bool sent, ) = owner().call{value: amount}("");

    require(sent, "Eth withdrawal failed");
  }

  // sellTokens() function
  function sellTokens(uint256 amountOfTokens) public {
    require(yourToken.allowance(msg.sender, address(this)) >= amountOfTokens, "Allowance too low");

    bool transferred = yourToken.transferFrom(msg.sender, address(this), amountOfTokens);
    require(transferred, "ERC20: Tokens could not be transferred");

    uint256 amountOfEth = amountOfTokens / tokensPerEth;
    require(amountOfEth <= address(this).balance, "Not enough ETH available");

    (bool sent, ) = msg.sender.call{value: amountOfEth}("");
    require(sent, "Eth transaction failed");

    emit SellTokens(msg.sender, amountOfTokens, amountOfEth);
  }

}
