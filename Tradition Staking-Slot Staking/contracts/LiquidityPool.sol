// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin/security/ReentrancyGuard.sol";
import "./ILiquidityPool.sol";

/**
 * @title Liqudity provider contract for rewards staking contract
 * @author https://anmol-dhiman.netlify.app/
 * @notice Provide USDC tokens only to verified address
 */
contract LiquidityPool is OwnableUpgradeable, ReentrancyGuard, ILiquidityPool {
    event ContractVerified(address contractAddress, uint32 timeStamp);
    event AccessedFunds(
        address contractAddress,
        string action,
        uint32 timeStamp
    );
    event AmountMigrated(uint256 amount, address newAddress, uint32 timeStamp);
    event OwnerAccessFunds(uint256 amount, uint32 timeStamp);

    /**
     * @notice mapping for verified contract which can be accessed by owner only
     */
    mapping(address => bool) public verifiedContract;

    modifier isVerified() {
        require(verifiedContract[msg.sender], "contract is not verified");
        _;
    }

    /**
     * @dev Proxy initializer function sets new owner other than admin
     * @param _owner The owner of this contract
     */
    function initialize(address _owner) external payable initializer {
        __Ownable_init();
        transferOwnership(_owner);
    }

    /**
     * @dev verficy the contract for access rewards
     * @notice this function can only accessed by owner
     * @param _contract is the contract address which can access USDC tokens
     */
    function verifyContract(address _contract) external onlyOwner {
        require(_contract != address(0), "invalid contract address");
        verifiedContract[_contract] = true;
        emit ContractVerified(_contract, uint32(block.timestamp));
    }

    /**
     * @dev verified contract can access USDC tokens with this function only
     * @param _amount the amount of USDC tokens required by contract
     * @param _action the purpose of USDC token
     * @notice only verified contracts by owner can access this function
     * @notice this function is non reentrant
     */
    function accessFunds(
        uint256 _amount,
        string memory _action
    ) external isVerified nonReentrant {
        address _contract = msg.sender;
        require(address(this).balance >= _amount, "No USDC tokens in pool");

        (bool success, ) = _contract.call{value: _amount}("");
        require(success, "failed to send USDC tokens");
        emit AccessedFunds(_contract, _action, uint32(block.timestamp));
    }

    fallback() external payable {}

    receive() external payable {}

    /**
     * @dev this function is used to migrate the USDC tokens from this contract to another EOA or contract
     * @param amount the amount of USDC tokens needed to migrate
     * @param newAddress the address on which USDC tokens should be sent
     * @notice this functions can only be called by owner
     * @notice this function is non reentrant
     */
    function migration(
        uint256 amount,
        address newAddress
    ) external nonReentrant onlyOwner {
        require(
            address(this).balance >= amount,
            "Contract insufficient balance"
        );
        require(amount > 0, "invalid amount");
        require(newAddress != address(0), "invalid address");
        emit AmountMigrated(amount, newAddress, uint32(block.timestamp));
        (bool success, ) = newAddress.call{value: amount}("");
        require(success, "Unable to send value or recipient may have reverted");
    }

    /**
     * @dev extract USDC tokens from this contract
     * @param _amount Specific amount of USDC token needed to be removed from this contract
     * @notice the contract owner can access this function
     * @notice this function is non reentrant
     */
    function extractFunds(uint256 _amount) external onlyOwner nonReentrant {
        require(
            address(this).balance >= _amount,
            "Contract insufficient balance"
        );
        require(_amount > 0, "invalid amount");
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Unable to send value or recipient may have reverted");
        emit OwnerAccessFunds(_amount, uint32(block.timestamp));
    }
}
