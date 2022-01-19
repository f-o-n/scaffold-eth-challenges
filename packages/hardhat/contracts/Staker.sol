// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  uint256 public constant threshold = 1 ether;

  ExampleExternalContract public exampleExternalContract;

  mapping ( address => uint256 ) public balances;

  uint256 public deadline = block.timestamp + 72 hours;//+ 60 seconds;

  bool public openForWithdraw = false;

  bool public executed = false;

  bool public locked;

  constructor(address exampleExternalContractAddress) {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  event Stake(address _from ,uint256 _value);

  modifier noReentrancy() {
    require(!locked, "No reentrancy");
    locked = true;
    _;
    locked = false;
  }

  modifier notCompleted() {
    bool completed = exampleExternalContract.completed();
    require(!completed, "Staking already completed");
    _;
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping
  // emit `Stake(address,uint256)` for the frontend <List/> display )
  function stake() public payable notCompleted {
    balances[msg.sender] += msg.value;
    emit Stake(msg.sender, msg.value);
  }

  // After some `deadline` allow anyone to call an `execute()` function
  // It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
  // Or open withdrawal
  function execute() public noReentrancy notCompleted {
    require(!executed, "Staking already executed");
    uint256 staked = address(this).balance;
    require(block.timestamp >= deadline || staked >= threshold, "Not there yet");

    executed = true;
    if(staked >= threshold) {
      exampleExternalContract.complete{value: staked}();
    } else {
      openForWithdraw = true;
    }
  }

  // if the `threshold` was not met, allow everyone to call a `withdraw()` function to withdraw balance
  function withdraw(address payable _to) public payable {
    require(openForWithdraw, "Withdrawal not open");

    uint256 amount = balances[msg.sender];
    require(amount > 0, "Nothing to withdraw");

    balances[msg.sender] = 0;
    (bool sent, ) = _to.call{value: amount}("");
    require(sent, "Withdrawal failed");
  }

  // Returns the time left before the deadline for the frontend
  function timeLeft() external view returns(uint256) {
    if(block.timestamp >= deadline || executed) {
      return 0;
    }

    return deadline - block.timestamp;
  }

  // Receives eth and calls stake()
  receive() external payable notCompleted {
    stake();
  }

}
