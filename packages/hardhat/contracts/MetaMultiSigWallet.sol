// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;


import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title Multi-Sig Wallet
 * @author alonsovargas.eth
 * @notice Multi-Sig Wallet uses a smart contract as a wallet and allows owners to approve and revoke transactions
 * NOTE: This was started from started from 🏗 scaffold-eth - meta-multi-sig-wallet example https://github.com/austintgriffith/scaffold-eth/tree/meta-multi-sig
 */
contract MetaMultiSigWallet {

    using ECDSA for bytes32;

    /* ========== GLOBAL VARIABLES ========== */

    /**
     * @notice List of wallet owners
     */
    address[] public owners;

    /**
     * @notice Mapping that will identify if an address is an owner
     */
    mapping(address => bool) public isOwner;

    /**
     * @notice The number of approvals that are required before tx can be executed
     */
    uint public approvalsRequired;

    /**
     * @notice Transaction struct
     */
    struct Transaction {
      address to;
      uint value;
      bytes data;
      bool executed;
      uint numApprovals;
    }

    /**
     * @notice List of tx's
     */
    Transaction[] public transactions;

    /**
     * @notice Mapping of transactions to addresses and whether the address has approved th tx
     */
    mapping(uint => mapping(address => bool)) public approved;

    //TODO
    //uint public nonce;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when deposits are made into the wallet
     */
    event Deposit(
      address indexed sender,
      uint amount,
      uint balance
    );

    event SubmitTransaction(
        address indexed owner,
        uint indexed txIndex,
        address indexed to,
        uint value,
        bytes data
    );

    /**
     * @notice Emitted when a tx is approved by an owner
     */
    event ApproveTransaction(
      address indexed owner,
      uint indexed txIndex
    );

    /**
     * @notice Emitted when a tx is revoked by an owner
     */
    event RevokeApproval(
      address indexed owner,
      uint indexed txIndex
    );

    /**
     * @notice Emitted when tx is executed and waiting for other owners to approve
     */
    event ExecuteTransaction(
      address indexed owner,
      uint indexed txIndex
    );

    /**
     * @notice Emitted when a new owner is added or removed
     */
    event Owner(
      address indexed owner,
      bool added
    );

    /* ========== CONSTRUCTOR ========== */

    constructor(address[] memory _owners, uint _approvalsRequired) {
        require(_owners.length > 0, "Constructor: owners required");
        require(_approvalsRequired > 0 && _approvalsRequired <= _owners.length, "Constructor: invalid number of approvals required");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Constructor: zero address");
            require(!isOwner[owner], "Constructor: owner is not unique");
            isOwner[owner] = true;
            owners.push(owner);
            emit Owner(owner, isOwner[owner]);
        }

        approvalsRequired = _approvalsRequired;
    }

    /* ========== FUNCTION MODIFIERS ========== */

    /**
     * @notice Only allows owners to run the function
     */
    modifier onlyOwner(){
      require(isOwner[msg.sender], "not owner");
      _;
    }

    /**
     * @notice Requires for the tx to exists in the transactions list
     */
    modifier txExists(uint _txId){
      require(_txId < transactions.length, "tx does not exist");
      _;
    }

    /**
     * @notice Requires that the tx is not yet approved
     */
    modifier notApproved(uint _txId){
      require(!approved[_txId][msg.sender], "tx already approved");
      _;
    }

    /**
     * @notice Requires that the tx is not yet executed
     */
    modifier notExecuted(uint _txId){
      require(!transactions[_txId].executed, "tx already executed");
      _;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
    @param _to Address where the ETH will be sent
    @param _value Amount of ETH that will be sent
    @param _data Data that will be sent with the transaction
    @notice Allows an owner to submit a transaction to for owners to approve
    */
    function submitTransaction(
      address _to,
      uint _value,
      bytes calldata _data
    ) external onlyOwner {

      transactions.push(
        Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numApprovals: 0
        })
      );

      uint txIndex = transactions.length - 1;

      emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    /**
    @param _txId The index of the tx
    @notice Allows an owner to approve a tx that exists, is not approve, and not executed
    */
    function approveTransaction(uint _txId)
      external
      onlyOwner
      txExists(_txId)
      notApproved(_txId)
      notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        transactions[_txId].numApprovals += 1;
        emit ApproveTransaction(msg.sender, _txId);
    }

    /**
    @param _txId The index of the tx
    @notice Allows an owner to execute an approved tx that has not yet been executed
    */
    function executeTransaction(uint _txId)
      external txExists(_txId)
      notExecuted(_txId)
    {
        require(_getApprovalCount(_txId) >= approvalsRequired, "Approvals is less than required approvals");
        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
          transaction.data
        );
        require(success, "tx failed");
        emit ExecuteTransaction(msg.sender, _txId);
    }

    /**
    @param _txId The index of the tx
    @notice Revokes approval for a tx that an owner has already approved. Useful if the user changes their mind after approving a tx
    */
    function revokeApproval(uint _txId)
      external
      onlyOwner
      txExists(_txId)
      notExecuted(_txId)
    {
      require(approved[_txId][msg.sender], "You have not approved this tx");
      approved[_txId][msg.sender] = false;
      emit RevokeApproval(msg.sender, _txId);
    }

    /**
    @param newSigner Address of new owner
    @param newApprovalsRequired New number of approvals required
    @notice Allows an owner to add additional owners and modify the number of approvals required
    */
    function addSigner(address newSigner, uint256 newApprovalsRequired)
      public
      onlyOwner
    {
        require(newSigner != address(0), "addSigner: zero address");
        require(!isOwner[newSigner], "addSigner: owner not unique");
        require(newApprovalsRequired > 0, "addSigner: must be non-zero sigs required");
        isOwner[newSigner] = true;
        approvalsRequired = newApprovalsRequired;
        emit Owner(newSigner, isOwner[newSigner]);
    }

    /**
    @param oldSigner Address of owner to be removed
    @param newApprovalsRequired New number of approvals required
    @notice Allows an owner to remove another owner and modify the number of approvals required
    */
    function removeSigner(address oldSigner, uint256 newApprovalsRequired)
      public
      onlyOwner
    {
        require(isOwner[oldSigner], "removeSigner: not owner");
        require(newApprovalsRequired > 0, "removeSigner: must be non-zero sigs required");
        isOwner[oldSigner] = false;
        approvalsRequired = newApprovalsRequired;
        emit Owner(oldSigner, isOwner[oldSigner]);
    }

    /**
    @param newApprovalsRequired Updated number of approvals required
    @notice Allows an owner to update the number of approvals required to execute a tx
    */
    function updateApprovalsRequired(uint256 newApprovalsRequired)
      public
      onlyOwner
    {
        require(newApprovalsRequired > 0, "updateApprovalsRequired: must be non-zero sigs required");
        approvalsRequired = newApprovalsRequired;
    }

    /* ========== READ FUNCTIONS ========== */

    /**
    @param _txId The index of the tx
    @notice Get the number of approvals for a transaction
    */
    function _getApprovalCount(uint _txId) private view returns (uint count){
      count = transactions[_txId].numApprovals;
    }

    /* ========== RECEIVE FUNCTION ========== */

    receive() payable external {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }


}
