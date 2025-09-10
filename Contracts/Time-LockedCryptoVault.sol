// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Time-Locked Crypto Vault
 * @dev A smart contract that allows users to deposit ETH with time-based locks
 * @author Your Name
 */
contract Project {
    // Struct to store vault information
    struct Vault {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }
    
    // Mapping from user address to their vaults (users can have multiple vaults)
    mapping(address => Vault[]) public userVaults;
    
    // Events
    event VaultCreated(address indexed user, uint256 indexed vaultId, uint256 amount, uint256 unlockTime);
    event VaultWithdrawn(address indexed user, uint256 indexed vaultId, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed vaultId, uint256 amount, uint256 penalty);
    
    // Emergency withdrawal penalty percentage (5%)
    uint256 public constant PENALTY_RATE = 5;
    uint256 public constant PERCENTAGE_BASE = 100;
    
    // Owner for emergency functions
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Core Function 1: Deposit ETH with a time lock
     * @param _lockDuration Duration in seconds to lock the funds
     */
    function createVault(uint256 _lockDuration) external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(_lockDuration > 0, "Lock duration must be greater than 0");
        
        uint256 unlockTime = block.timestamp + _lockDuration;
        
        // Create new vault
        Vault memory newVault = Vault({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false
        });
        
        userVaults[msg.sender].push(newVault);
        uint256 vaultId = userVaults[msg.sender].length - 1;
        
        emit VaultCreated(msg.sender, vaultId, msg.value, unlockTime);
    }
    
    /**
     * @dev Core Function 2: Withdraw funds after lock period expires
     * @param _vaultId The ID of the vault to withdraw from
     */
    function withdrawVault(uint256 _vaultId) external {
        require(_vaultId < userVaults[msg.sender].length, "Vault does not exist");
        
        Vault storage vault = userVaults[msg.sender][_vaultId];
        require(!vault.withdrawn, "Vault already withdrawn");
        require(block.timestamp >= vault.unlockTime, "Vault is still locked");
        require(vault.amount > 0, "Vault is empty");
        
        uint256 amount = vault.amount;
        vault.withdrawn = true;
        vault.amount = 0;
        
        // Transfer funds to user
        payable(msg.sender).transfer(amount);
        
        emit VaultWithdrawn(msg.sender, _vaultId, amount);
    }
    
    /**
     * @dev Core Function 3: Emergency withdraw with penalty (before unlock time)
     * @param _vaultId The ID of the vault to withdraw from
     */
    function emergencyWithdraw(uint256 _vaultId) external {
        require(_vaultId < userVaults[msg.sender].length, "Vault does not exist");
        
        Vault storage vault = userVaults[msg.sender][_vaultId];
        require(!vault.withdrawn, "Vault already withdrawn");
        require(vault.amount > 0, "Vault is empty");
        require(block.timestamp < vault.unlockTime, "Use regular withdraw, lock period expired");
        
        uint256 penalty = (vault.amount * PENALTY_RATE) / PERCENTAGE_BASE;
        uint256 withdrawAmount = vault.amount - penalty;
        
        vault.withdrawn = true;
        vault.amount = 0;
        
        // Transfer funds to user (minus penalty)
        payable(msg.sender).transfer(withdrawAmount);
        
        emit EmergencyWithdraw(msg.sender, _vaultId, withdrawAmount, penalty);
    }
    
    // View functions
    
    /**
     * @dev Get vault information for a user
     * @param _user The user address
     * @param _vaultId The vault ID
     */
    function getVaultInfo(address _user, uint256 _vaultId) external view returns (
        uint256 amount,
        uint256 unlockTime,
        bool withdrawn,
        bool canWithdraw,
        uint256 timeRemaining
    ) {
        require(_vaultId < userVaults[_user].length, "Vault does not exist");
        
        Vault memory vault = userVaults[_user][_vaultId];
        
        amount = vault.amount;
        unlockTime = vault.unlockTime;
        withdrawn = vault.withdrawn;
        canWithdraw = !withdrawn && block.timestamp >= unlockTime;
        
        if (block.timestamp >= unlockTime) {
            timeRemaining = 0;
        } else {
            timeRemaining = unlockTime - block.timestamp;
        }
    }
    
    /**
     * @dev Get the number of vaults for a user
     * @param _user The user address
     */
    function getUserVaultCount(address _user) external view returns (uint256) {
        return userVaults[_user].length;
    }
    
    /**
     * @dev Get contract balance (accumulated penalties)
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Calculate emergency withdrawal amounts
     * @param _user The user address
     * @param _vaultId The vault ID
     */
    function calculateEmergencyWithdraw(address _user, uint256 _vaultId) external view returns (
        uint256 withdrawAmount,
        uint256 penalty
    ) {
        require(_vaultId < userVaults[_user].length, "Vault does not exist");
        
        Vault memory vault = userVaults[_user][_vaultId];
        require(!vault.withdrawn && vault.amount > 0, "Invalid vault state");
        
        penalty = (vault.amount * PENALTY_RATE) / PERCENTAGE_BASE;
        withdrawAmount = vault.amount - penalty;
    }
    
    // Owner functions
    
    /**
     * @dev Owner can withdraw accumulated penalties (emergency function)
     */
    function withdrawPenalties() external {
        require(msg.sender == owner, "Only owner can withdraw penalties");
        
        uint256 balance = address(this).balance;
        require(balance > 0, "No penalties to withdraw");
        
        payable(owner).transfer(balance);
    }
    
    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "New owner cannot be zero address");
        
        owner = newOwner;
    }
}
