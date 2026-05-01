// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

contract EscrowService {
    //states to track the progress of transactions
    enum State { AWAITING_DEPOSIT, AWAITING_DELIVERY, COMPLETE, REFUNDED, DISPUTED }
    // How the dispute was resolved
    enum DisputeResolution { NONE, REFUND_BUYER, PAY_SELLER }

    struct Transaction {
        address buyer;
        address seller;
        uint256 amount;
        State state;
        bool buyerApproved;
        bool arbiterInvolved;
        DisputeResolution disputeResolution;
    }

    address public arbiter;
    mapping(uint256 => Transaction) public transactions;
    uint256 private transactionCount;

    event TransactionCreated(uint256 transactionId, address buyer, address seller, uint256 amount);
    event FundsDeposited(uint256 transactionId, uint256 amount);
    event DeliveryApproved(uint256 transactionId);
    event DisputeRaised(uint256 transactionId);
    event DisputeResolved(uint256 transactionId, DisputeResolution resolution);
    event FundsReleased(uint256 transactionId, address recipient, uint256 amount);
    event Refunded(uint256 transactionId, uint256 amount);

    constructor() {
        arbiter = msg.sender;
    }

 // Only the buyer can create transaction
 //Creates new transaction with given seller
    function createTransaction(address seller) public returns (uint256) {
        require(seller != address(0), "Invalid seller address");
        require(seller != msg.sender, "Buyer cannot be the seller");

        uint256 transactionId = transactionCount++;
        transactions[transactionId] = Transaction({
            buyer: msg.sender,
            seller: seller,
            amount: 0,
            state: State.AWAITING_DEPOSIT, //Setting state to await deposite
            buyerApproved: false,
            arbiterInvolved: false,
            disputeResolution: DisputeResolution.NONE
        });

        emit TransactionCreated(transactionId, msg.sender, seller, 0);
        return transactionId;
    }

 //Buyer sends ETH to this function
    function depositFunds(uint256 transactionId) public payable {
        Transaction storage transaction = transactions[transactionId];
        
        require(msg.sender == transaction.buyer, "Only buyer can deposit");
        require(transaction.state == State.AWAITING_DEPOSIT, "Invalid state");
        require(msg.value > 0, "Deposit amount must be greater than 0");

        transaction.amount = msg.value;
        transaction.state = State.AWAITING_DELIVERY; // Update the status to await deleviry

        emit FundsDeposited(transactionId, msg.value);
    }

//When buyer approves delivery of product, funds are sent to seller
    function approveDelivery(uint256 transactionId) public {
        Transaction storage transaction = transactions[transactionId];
        
        require(msg.sender == transaction.buyer, "Only buyer can approve delivery");
        require(transaction.state == State.AWAITING_DELIVERY, "Invalid transaction state");

        transaction.buyerApproved = true;
        _releaseFunds(transactionId);

        emit DeliveryApproved(transactionId);
    }

//Buyer can raise dispute if they didnt recieve the product, Now the third person is involved
    function raiseDispute(uint256 transactionId) public {
        Transaction storage transaction = transactions[transactionId];
        
        require(msg.sender == transaction.buyer, "Only the buyer can raise a dispute");
        require(transaction.state == State.AWAITING_DELIVERY, "Invalid transaction state");

        transaction.arbiterInvolved = true;

        emit DisputeRaised(transactionId);
    }

    //Only Arbiter can resolve dispute, can refund or pay the seller
    function resolveDispute(uint256 transactionId, DisputeResolution resolution) public {
        Transaction storage transaction = transactions[transactionId];
        
        require(msg.sender == arbiter, "Only the arbiter can resolve disputes");
        require(transaction.arbiterInvolved, "Arbiter not involved in this transaction");
        require(transaction.state == State.AWAITING_DELIVERY, "Invalid transaction state");
        require(resolution == DisputeResolution.REFUND_BUYER || resolution == DisputeResolution.PAY_SELLER, "Invalid resolution");

        transaction.disputeResolution = resolution;

        //Refund buyer
        if (resolution == DisputeResolution.REFUND_BUYER) {
            _refundBuyer(transactionId);
        //Pay the seller
        } else if (resolution == DisputeResolution.PAY_SELLER) {
            _releaseFunds(transactionId);
        }

        emit DisputeResolved(transactionId, resolution);
    }

    //Helper function for resolving dispute,send money to seller
    function _releaseFunds(uint256 transactionId) internal {
        Transaction storage transaction = transactions[transactionId];
        
        require(transaction.state == State.AWAITING_DELIVERY, "Invalid transaction state");
        require(transaction.buyerApproved || 
               (transaction.arbiterInvolved && transaction.disputeResolution == DisputeResolution.PAY_SELLER), 
               "Not authorized to release funds");

        transaction.state = State.COMPLETE;
        
        (bool success, ) = payable(transaction.seller).call{value: transaction.amount}("");
        require(success, "Failed to release funds to seller");

        emit FundsReleased(transactionId, transaction.seller, transaction.amount);
    }

    //Helper function for resolving dispute,send money to buyer
    function _refundBuyer(uint256 transactionId) internal {
        Transaction storage transaction = transactions[transactionId];
        
        require(transaction.state == State.AWAITING_DELIVERY, "Invalid transaction state");
        require(transaction.arbiterInvolved && transaction.disputeResolution == DisputeResolution.REFUND_BUYER, 
                "Not authorized to refund");

        transaction.state = State.REFUNDED;
        
        (bool success, ) = payable(transaction.buyer).call{value: transaction.amount}("");
        require(success, "Failed to refund buyer");

        emit Refunded(transactionId, transaction.amount);
    }

    //Returns transaction details
    function getTransaction(uint256 transactionId) public view returns (
        address buyer,
        address seller,
        uint256 amount,
        State state,
        bool buyerApproved,
        bool arbiterInvolved,
        DisputeResolution disputeResolution
    ) {
        Transaction storage transaction = transactions[transactionId];
        return (
            transaction.buyer,
            transaction.seller,
            transaction.amount,
            transaction.state,
            transaction.buyerApproved,
            transaction.arbiterInvolved,
            transaction.disputeResolution
        );
    }
}