// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.00;

contract VotingSystem {
    struct Candidate {
        string name;
        uint256 voteCount;
    }

    address public admin;
    mapping(address => bool) public registeredVoters;
    mapping(address => bool) public hasVoted;
    Candidate[] public candidates;
    uint256 public votingDeadline;
    bool public votingEnded;

    event VoterRegistered(address voter);
    event CandidateAdded(string name);
    event VoteCast(address voter, uint256 candidateId);
    event VotingEnded(string winnerName, uint256 winnerVotes);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(registeredVoters[msg.sender], "Only registered voters can call this function");
        _;
    }

    modifier onlyBeforeDeadline() {
        require(block.timestamp < votingDeadline, "Voting period has ended");
        _;
    }

    modifier votingNotEnded() {
        require(!votingEnded, "Voting has already ended");
        _;
    }

    constructor(uint256 durationInMinutes) {
        admin = msg.sender;
        // Setting the deadline
        votingDeadline = block.timestamp + (durationInMinutes * 1 minutes);
    }

   //Registering voter
   //Inherit from only Admin so only admin can register voter
    function registerVoter(address voter) public onlyAdmin votingNotEnded {
        //Cant register a voter twice
        require(!registeredVoters[voter], "Voter is already registered");
        registeredVoters[voter] = true;
        emit VoterRegistered(voter);
    }

    //Add candidate only by admin
    function addCandidate(string memory name) public onlyAdmin votingNotEnded {
        candidates.push(Candidate({
            name: name,
            voteCount: 0
        }));
        emit CandidateAdded(name);
    }

   //vote, candidate should be registered, vote should be before deadline 
    function vote(uint256 candidateId) public onlyRegisteredVoter onlyBeforeDeadline votingNotEnded {
        //Cant vote twice
        require(!hasVoted[msg.sender], "You have already voted");
        //Cant vote to non existing candidate, candidate id is auto increasing index
        require(candidateId < candidates.length, "Invalid candidate ID");

        //Turn on has voted to not allow multiple votes
        hasVoted[msg.sender] = true;
        candidates[candidateId].voteCount++;

        emit VoteCast(msg.sender, candidateId);
    }

    //endVoting, end only by admin
    function endVoting() public onlyAdmin votingNotEnded {
        //Require the voting period to end
        require(block.timestamp >= votingDeadline, "Voting period has not ended yet");

        uint256 winningCandidateId = getWinningCandidateId();
        votingEnded = true;

        emit VotingEnded(candidates[winningCandidateId].name, candidates[winningCandidateId].voteCount);
    }

    // get the winner after the timer has completed
    function getWinner() public view returns (string memory winnerName, uint256 winnerVotes) {
        require(votingEnded, "Voting has not ended yet");
        uint256 winningCandidateId = getWinningCandidateId();
        return (candidates[winningCandidateId].name, candidates[winningCandidateId].voteCount);
    }

    //helper function for getting candidate id for getting winner id
    function getWinningCandidateId() internal view returns (uint256 winningCandidateId) {
        uint256 winningVoteCount = 0;
        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i].voteCount > winningVoteCount) {
                winningVoteCount = candidates[i].voteCount;
                winningCandidateId = i;
            }
        }
        return winningCandidateId;
    }

    //Function to see how much time is left
    function getTimeRemaining() public view returns (uint256) {
        if (block.timestamp >= votingDeadline) {
            return 0;
        } else {
            return votingDeadline - block.timestamp;
        }
    }
}