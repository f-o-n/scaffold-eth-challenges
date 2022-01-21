pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT
// import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEX {

  using SafeMath for uint256;

  IERC20 token;

  uint256 public totalLiquidity;
  mapping (address => uint256) public liquidity;

  constructor(address token_addr) {
    token = IERC20(token_addr);
  }

  function init(uint256 tokens) public payable returns (uint256) {
    require(totalLiquidity == 0,"DEX:init - already has liquidity");

    totalLiquidity = address(this).balance;
    liquidity[msg.sender] = totalLiquidity;

    require(token.transferFrom(msg.sender, address(this), tokens));
    return totalLiquidity;
  }

  function price(uint256 input_amount, uint256 input_reserve, uint256 output_reserve)
    public pure returns (uint256) {

    uint256 input_amount_with_fee = input_amount.mul(997);
    uint256 numerator = input_amount_with_fee.mul(output_reserve);
    uint256 denominator = input_reserve.mul(1000).add(input_amount_with_fee);

    return numerator / denominator;
  }

  function ethToToken() public payable returns (uint256) {

    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_reserve = address(this).balance.sub(msg.value);

    uint256 tokens_bought = price(msg.value, eth_reserve, token_reserve);

    bool token_sent = token.transfer(msg.sender, tokens_bought);
    require(token_sent, "ERC20: Buy tokens failed");

    return tokens_bought;
  }

  function tokenToEth(uint256 tokens) public returns (uint256) {

    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_reserve = address(this).balance;

    uint256 eth_bought = price(tokens, token_reserve, eth_reserve);

    (bool eth_sent, ) = msg.sender.call{value: eth_bought}("");
    require(eth_sent, "ERC20: Sending ETH failed");

    bool token_received = token.transferFrom(msg.sender, address(this), tokens);
    require(token_received, "ERC20: Selling Tokens failed");

    return eth_bought;
  }

  function deposit() public payable returns (uint256) {
    uint256 eth_reserve = address(this).balance.sub(msg.value);
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 token_amount = (msg.value.mul(token_reserve) / eth_reserve).add(1);

    uint256 liquidity_minted = msg.value.mul(totalLiquidity) / eth_reserve;
    liquidity[msg.sender] = liquidity[msg.sender].add(liquidity_minted);
    totalLiquidity = totalLiquidity.add(liquidity_minted);

    bool token_received = token.transferFrom(msg.sender, address(this), token_amount);
    require(token_received, "ERC20: Token transfer failed");

    return liquidity_minted;
  }

  function withdraw(uint256 amount) public returns (uint256, uint256) {
    uint256 token_reserve = token.balanceOf(address(this));
    uint256 eth_amount = amount.mul(address(this).balance) / totalLiquidity;
    uint256 token_amount = amount.mul(token_reserve) / totalLiquidity;

    liquidity[msg.sender] = liquidity[msg.sender].sub(eth_amount);
    totalLiquidity = totalLiquidity.sub(eth_amount);

    (bool eth_sent, ) = msg.sender.call{value: eth_amount}("");
    require(eth_sent, "ERC20: Sending ETH failed");

    bool token_sent = token.transfer(msg.sender, token_amount);
    require(token_sent, "ERC20: Sending Tokens failed");

    return (eth_amount, token_amount);
  }


}
