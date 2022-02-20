// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { ABDKMath64x64 } from  "./ABDKMath64x64.sol";

/**
 * ETH pool which us
 * Using Scalable reward dist algorithm for calculating reward distributions: 
 * https://www.semanticscholar.org/paper/Scalable-Reward-Distribution-on-the-Ethereum-Batog-Boca/957c5ff70ae428b4722555e9d0c33d03c1addf2f
 * Assumptions :
    -  User Should withdraw all staked funds before depositing (staked[personj](t) == staked[personj](t-1) == constant)
 */
contract ETHPool is  ReentrancyGuard, Ownable, AccessControl {

    using ABDKMath64x64 for uint256;
    using ABDKMath64x64 for int128;


    event WithdrawReward( address user ,uint256 deposited, uint256 rewards, uint256 totalWithdrawn);



    bytes32 public constant TEAM_MEMBER_ROLE = keccak256("TEAM_MEMBER_ROLE");
    uint256 public totalDeposits = 0;
    int128 public current_reward_deposits_rate = 0;
    // Note reward_deposits_rate :  S[t] = reward[t] / totalRewards [t]
    mapping(address => int128) public initial_reward_deposits_rate;
    mapping(address => uint256) public stake;

    constructor() {
        _setupRole(TEAM_MEMBER_ROLE, msg.sender);
    }

    //
    //  TEAM MEMBER ROLE
    //

    function isTeamMember(address _teamMember) external view returns (bool) {
        return hasRole(TEAM_MEMBER_ROLE, _teamMember);
    }

    function addTeamMember(address _newTeamMember) external onlyOwner {
        _setupRole(TEAM_MEMBER_ROLE, _newTeamMember);
    }

    function removeTeamMember(address _teamMember) external onlyOwner {
        _revokeRole(TEAM_MEMBER_ROLE, _teamMember);
    }


    function deposit() external payable  {
        require(msg.value > 0, "ETH amount Should be Positive");
        require(stake[msg.sender] == 0,'Should withdraw funds before depositing');

        stake[msg.sender] = msg.value;
        totalDeposits = totalDeposits + msg.value;
        initial_reward_deposits_rate[msg.sender] = current_reward_deposits_rate;
    }

    /**

     * Todo Check numerical precision
     */
    function distributeReward() external payable onlyRole(TEAM_MEMBER_ROLE) {
        require(msg.value > 0, "Should have reward to distribute");
        require(totalDeposits > 0,'Should have stake amount to calculate stake / reward rate');
        current_reward_deposits_rate = current_reward_deposits_rate +   msg.value.divu(totalDeposits);

    }


    function withdraw() external 
        nonReentrant() 
        returns (uint256){
        require(stake[msg.sender] > 0,'No funds to withdraw');
        
        uint256 deposited = stake[msg.sender]; 
        int128 rate_diff =current_reward_deposits_rate.sub(initial_reward_deposits_rate[msg.sender]); 
        uint256 reward =   rate_diff.mulu(deposited); 
        totalDeposits = totalDeposits - deposited;
        uint256 withdrawAmount = deposited + reward; 
        stake[msg.sender] = 0;
        (bool sent, bytes memory data) = msg.sender.call{value: withdrawAmount}("");
        emit WithdrawReward(msg.sender,deposited, reward, withdrawAmount);
        require(sent, "Failed to send Ether");
        return withdrawAmount;
    }




}