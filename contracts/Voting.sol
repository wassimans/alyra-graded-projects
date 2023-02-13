// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        // Added proposalId to the struct for more clarity
        uint proposalId;
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    // Main data structure to maintain a list of voters by account address.
    mapping (address => Voter) public whitelist;
    // An array to hold all the proposals being voted upon, this will come handy to count total votes for a proposal.
    Proposal[] public proposalList;
    // An array of the voters addresses. Will be used to iterate on the whitelist mapping in order to reset the mapping's data.
    address[] public voterList;
    // A variable to hold the workflow status at any given time.
    WorkflowStatus public workflowStatus;
    // A variable to hold the winning proposal ID
    uint public winningProposalId;
    // Every time a proposal is added this variable is incremented and will represent the new proposal's ID
    // I prefer to set the ID in the contract rather than in the frontend
    uint private proposalIdCounter = 0;

    // Make sure the voter is already registred in the whitelist
    modifier voterAlreadyExists(address _address) {
        bool isVoterRegistred = whitelist[_address].isRegistered;
        require(isVoterRegistred, "Voter not registred!");
        _;
    }

    // Make sure this is the first time the voter is casting his vote for this proposal
    modifier voterDidnotVote(address _address, uint _votedProposalId) {
        bool hasVoted = whitelist[_address].hasVoted;
        bool hasVotedProposalId = whitelist[_address].votedProposalId == _votedProposalId;
        require(!hasVoted && !hasVotedProposalId, "Voter already made his vote for this Proposal!");
        _;
    }

    /**
     * @dev Register new voter.
     * @param _address The address of the voter.
     */
    function registerNewVoter(address _address) external onlyOwner voterAlreadyExists(_address) {
        Voter memory newVoter = Voter(true, false, 0);
        whitelist[_address] = newVoter;
        voterList.push(_address);
        emit VoterRegistered(_address);
    }

    /**
     * @dev Start proposal registration process.
     */
    function startProposalsRegistrationSession() external onlyOwner {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * @dev Register a proposal.
     * @param _address The address of the voter who's proposing the new proposal.
     * @param _proposalDescription Proposal description.
     */
    function registerProposal(address _address, string memory _proposalDescription) public voterAlreadyExists(_address) {
        proposalIdCounter++;
        Proposal memory newProposal = Proposal(proposalIdCounter, _proposalDescription, 0);
        proposalList.push(newProposal);
        emit ProposalRegistered(proposalIdCounter);
    }

    /**
     * @dev end proposal registration process.
     */
    function endProposalsRegistrationSession() external onlyOwner {
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * @dev Start voting session.
     */
    function startVotingSession() external onlyOwner {
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * @dev Add a new payee to the contract.
     * @param _address The voter's address.
     * @param _proposalId The ID of the proposal.
     */
    function voteOnProposal(address _address, uint _proposalId) public voterAlreadyExists(_address) voterDidnotVote(_address, _proposalId) {
        Voter memory voter = whitelist[_address];
        proposalList[_proposalId].voteCount++;
        voter.hasVoted = true;
        voter.votedProposalId = _proposalId;
        emit Voted(_address, _proposalId);
    }

    /**
     * @dev End voting session.
     */
    function endVotingSession() external onlyOwner {
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * @dev Count the votes and determine the winner proposal
     */
    function countVotes() external onlyOwner {
        uint tmp = 1;
        for (uint i = 0; i < proposalList.length; i++) {
            if (proposalList[i].voteCount > tmp) {
                tmp = proposalList[i].voteCount;
                winningProposalId = proposalList[i].proposalId;
            } else {
                continue;
            }
        }
    }

    /**
     * @dev All votes are tallied.
     */
    function votesTallied() external onlyOwner {
        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    /**
     * @dev Reset the data structures in order to begin a new voting session.
     */
    function resetData() external onlyOwner  {
        delete proposalList;
        for (uint i = 0; i < voterList.length; i++) {
            whitelist[voterList[i]].hasVoted = false;
            whitelist[voterList[i]].votedProposalId = 999999;
        }
    }

    /**
     * @dev Getter for the winner proposal ID
     */
    function getWinner() public view returns (uint) {
        return winningProposalId;
    }

    /**
     * @dev Getter for the current workflow status.
     */
    function getWorkflowStatus() public view returns (WorkflowStatus) {
        return workflowStatus;
    }
}