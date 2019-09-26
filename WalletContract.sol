pragma solidity ^0.5.0;

import "./SwipeOracle.sol";

// ----------------------------------------------------------------------------

// StateLock is Card Lock State Contract

// ----------------------------------------------------------------------------
contract StateLock is Owned {
     using SafeMath for uint;

    // ----------------------------------------------------------------------------

    // Card Lock State Data

    // ----------------------------------------------------------------------------
    struct stateLockData {
        uint id;
        uint amount;
        uint releaseTime;
    }

    stateLockData[] lockData;
    uint constant error = 2**256 - 1;


    // ----------------------------------------------------------------------------

    // Constructor

    // ----------------------------------------------------------------------------
    constructor() public {

    }


    // ----------------------------------------------------------------------------

    // Check Locked Cards Status Response

    // - count   : Locked Cards Count

    // - ids     : Locked Card Indexes Array

    // - amounts : Locked Card Amount Array

    // - expireTimes : Locked Card Expire Time Array

    // ----------------------------------------------------------------------------
    function viewLocked() public view returns(uint count, uint[] memory ids, uint[] memory amounts, uint[] memory expireTimes) {
        count = lockData.length;
        ids = new uint[](count);
        amounts = new uint[](count);
        expireTimes = new uint[](count);

        for (uint i = 0; i < lockData.length; i ++) {
            ids[i] = lockData[i].id;
            amounts[i] = lockData[i].amount;
            expireTimes[i] = lockData[i].releaseTime;
        }
    }


    // ----------------------------------------------------------------------------

    // Get Total Locked Amount

    // - amount : Locked Card Amount Array

    // ----------------------------------------------------------------------------
    function getLockedAmount() public view returns(uint amount) {
        amount = 0;
        for (uint i = 0; i < lockData.length; i ++) {
            amount = amount.add(lockData[i].amount);
        }

        return amount;
    }


    // ----------------------------------------------------------------------------

    // Get Locked Card By Id

    // - uint : Locked Card

    // ----------------------------------------------------------------------------
    function findLockState(uint _id) private view returns(uint) {
        for (uint i = 0; i < lockData.length; i ++) {
            if (lockData[i].id == _id) {
                return i;
            }
        }

        return error;
    }


    // ----------------------------------------------------------------------------

    // Remove Locked Card in Data Storage By Id

    // - i : Card Index For Removal

    // ----------------------------------------------------------------------------
    function removeByIndex(uint i) private {
        if (i < lockData.length) {
            lockData[i] = lockData[lockData.length-1];
            lockData.length--;
        }
    }


    // ----------------------------------------------------------------------------

    // Lock Card with Amount and Lock Time

    // - _id : Lock Card Index

    // - amount : Lock Amount

    // - _lockTime : Lock Expire Time

    // ----------------------------------------------------------------------------
    function cardLock(uint _id, uint _amount, uint _lockTime) public onlyOwner {
        require(findLockState(_id) == error, 'already locked');
        lockData.push(stateLockData(_id, _amount, now.add(_lockTime)));
    }


    // ----------------------------------------------------------------------------

    // Unlock Card By Index

    // - _id : Card Index For Unlock

    // ----------------------------------------------------------------------------
    function cardUnlock(uint _id) public onlyOwner{
        uint index = findLockState(_id);
        require(index != error, 'cannot find lock');
        require(lockData[index].releaseTime <= now, 'not passed lock time');

        removeByIndex(index);
    }
}


// ----------------------------------------------------------------------------

// Wallet Contract Inherited by StateLock

// ----------------------------------------------------------------------------
contract WalletContract is StateLock {
    using SafeMath for uint;

    // Wallet Contract SXP Balance
    SwipeToken public token;

    // Swipe Oracle Instance
    SwipeOracle public swipeOracle;

    bool public activated = false;
    uint lockedSXP = 0;

    event Activate(address indexed tokenOwner);


    // ----------------------------------------------------------------------------

    // Constructor

    // - _token : SXP Contract Address

    // - _token : SXP Contract Address

    // ----------------------------------------------------------------------------
    constructor(address payable _token, address oracle) public {
        token = SwipeToken(_token);
        swipeOracle = SwipeOracle(oracle);
    }


    // ----------------------------------------------------------------------------

    // Set Swipe Oracle Contract By Owner

    // - oracle : Swipe Oracle Contract Address

    // ----------------------------------------------------------------------------
    function setOracle(address oracle) public onlyOwner {
        swipeOracle = SwipeOracle(oracle);
    }


    // ----------------------------------------------------------------------------

    // Activate Wallet Contract With Activation Fee By Owner

    // ----------------------------------------------------------------------------
    function activateSXP() public onlyOwner {
        uint activationFee = swipeOracle.viewActivationFee();
        require(getBalance() >= activationFee, 'not enough balance');

        activated = true;

        lockedSXP = activationFee;

        emit Activate(address(this));
    }


    // ----------------------------------------------------------------------------

    // Deactivate Wallet Contract And Withdraw Activation Fee SXP To Owner

    // ----------------------------------------------------------------------------
    function deactivateSXP() public onlyOwner returns (bool success) {
        require(activated == true, 'user is not activated');
        require(lockedSXP > 0, 'there is no activation fee');

        if (token.transfer(owner, lockedSXP)) {
            lockedSXP = 0;
            return true;
        }

        return false;
    }


    // ----------------------------------------------------------------------------

    // Get Wallet Contract SXP Balance

    // ----------------------------------------------------------------------------
    function getBalance() public view returns(uint) {
        return token.balanceOf(address(this));
    }


    // ----------------------------------------------------------------------------

    // Get Network Fee

    // ----------------------------------------------------------------------------
    function networkFee() public view returns(uint) {
        return swipeOracle.viewNetworkFee();
    }


    // ----------------------------------------------------------------------------

    // Withdraw Unlocked Available SXP To External Address By Owner

    // - to : External Address To Receive SXP

    // - tokenAmount: Amount To Withdraw

    // ----------------------------------------------------------------------------
    function transferSXP(address to, uint tokenAmount) public onlyOwner returns (bool success) {
        require(activated == true, 'user is not activated');
        require(getBalance() >= tokenAmount.add(lockedSXP).add(getLockedAmount()), 'not enough balance');

        if (token.transfer(to, tokenAmount)) {
            return true;
        }

        return false;
    }


    // ----------------------------------------------------------------------------

    // Transaction SXP Token With Network Fee And Oracle Fee

    // - tokenAmount: Amount To Transact

    // ----------------------------------------------------------------------------
    function transactionSXP(uint tokenAmount) public onlyOwner returns (bool success) {
        require(activated == true, 'user is not activated');
        require(getBalance() >= tokenAmount.add(lockedSXP).add(getLockedAmount()), 'not enough balance');

        uint netFee = swipeOracle.viewNetworkFee();
        uint oracleFee = swipeOracle.viewOracleFee();
        uint burnAmount = tokenAmount.mul(netFee).div(100);
        uint fee = tokenAmount.mul(oracleFee).div(100);
        if (token.burn(burnAmount)) {
            token.transfer(owner, fee);
            return true;
        }

        return false;
    }
}