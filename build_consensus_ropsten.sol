pragma solidity ^0.7.*;

contract BuildContract {
    
    enum Stage{
        register,
        commit,
        reveal,
        distribute
    }
    
    // struct ipfsHash{
    //     bytes32 commitment,
    //     bytes32 salt,
    //     bytes32 ipfsHash
    // }
    
    struct buildSubmission{
        address buildParticipant;
        bytes32 commitment;
        bytes32 buildHash;
    }
    
    mapping (address => uint) participant;
    
    // Initialization variables
    bytes32 public ipfsHash;
    uint public numParticipants;
    uint public currParticipants;
    uint public Reward;
    uint public RevealSpan;
    uint public participantPayout;
    
    // System variables
    bytes32 public buildId = "";
    Stage public stage = Stage.register;
    uint fundsTransferred = 0;
    uint public revealDeadline;
    uint public commitedParticipants = 0;
    uint public revealedParticipants = 0;
    buildSubmission[] public submissions;
    address public payer;
    
    // Events
    event BReqAccepted(address _payor, bytes32 _buildId, uint _numParticipants, uint _reward, uint _participantPayout, uint _revealSpan);
    event BReqRejected(address _payor, bytes32 _buildId, uint _numParticipants, uint _reward, uint _participantPayout, uint _revealSpan);
    event PartcipantRegistered(address _participant, bytes32 _buildId);
    event BuildOpened(bytes32 _buildId, bytes32 _ipfsHash);
    event BuildCommited(address _participant, bytes32 _commitment);
    event allBuildsCommitted(bytes32 _buildId);
    event BuildRevealed(bytes32 _buildId, address _participant);
    event BuildRevealFailed(bytes32 _buildId, address _participant);
    event allBuildsRevealed(bytes32 _buildId);
    event revealDeadlinePassed(bytes32 _buildId);
    event Payout(bytes32 _buildId, address _participant, uint _participantPayout);
    event BuildClosed(bytes32 _buildId, bytes32 _truebuildHash);
    
    // Public Contract Methods
    function addBReq(bytes32 _ipfshash, uint numP, uint _reward, uint _revealSpan) public payable returns (bool) {
        require(_ipfshash != "", "ipfsHash cannot be empty");
        require(_reward > 0, "Reward cannot be zero");
        require(_revealSpan > 0 && _revealSpan < 1000000, "revealSpan cannot be 0 or too long");
        require(msg.value >= _reward, "Value must be greater than reward amount");
        
        assert((_reward/numParticipants) > 0);
        participantPayout = _reward/numParticipants;
        assert(participantPayout*numParticipants <= _reward);
        
        if (buildId != "" || stage != Stage.register){
            emit BReqRejected(msg.sender, keccak256(abi.encode(payer, _ipfshash)), numParticipants, _reward, participantPayout, _revealSpan);
        }
        
        // Set internal state
        buildId = keccak256(abi.encode(payer, _ipfshash));
        //delete submissions;
        buildSubmission[numParticipants] storage submissions;
        payer = msg.sender;
        ipfsHash = _ipfshash;
        numParticipants = numP;
        currParticipants = 0;
        Reward = _reward;
        RevealSpan = _revealSpan;

        emit BReqAccepted(msg.sender, keccak256(abi.encodePacked(payer, ipfsHash)), numParticipants, Reward, participantPayout, RevealSpan);
        return (true);
    }
    
    
    function getBReq() public returns (address, bytes32, uint, uint, uint) {
        require(buildId != "" && stage != Stage.register, "No build request pending");
        return (payer, buildId, numParticipants, Reward, RevealSpan);
    }
    
    
    function regParticipant(bytes32 _buildId) public returns (bool) {
        require(stage == Stage.register && _buildId != "", "No build request pending");
        require(currParticipants < numParticipants, "participants full");
        require(_buildId == buildId, "No build pending against this bId");
        
        buildSubmission[currParticipants] = buildSubmission(msg.sender, "", "");
        participant[msg.sender] = currParticipants;
        currParticipants = currParticipants + 1;
        emit PartcipantRegistered(buildSubmission[currParticipants].buildParticipant, buildId);
        
        // Move to next stage if participants full
        if (currParticipants == numParticipants) {
            stage = Stage.commit;
            emit BuildOpened(buildId, ipfsHash);
        }
        return (true);
    }
    
    
    function getParticipants(bytes32 _buildId) public returns (uint, uint , buildSubmission[] memory) {
        require(_buildId == buildId, "No build pending against bId");
        return (currParticipants, numParticipants, submissions);
    }
    
    
    function getIpfsHash(bytes32 _buildId) public returns (bytes32) {
        require(_buildId == buildId, "No build pending against bId");
        return (ipfsHash);
    }
    
    
    function commitBuild(bytes32 _buildId, bytes32 _commitment) public returns (bool) {
        require(stage == Stage.commit, "Current build not at commit stage");
        require(_commitment != "", "Build commitment cannot be empty");
        require(_buildId == buildId, "No pending build against bId");
        require(submissions[participant[msg.sender]].commitment == "", "Participant already commited build hash");
        submissions[participant[msg.sender]].commitment = _commitment;
        commitedParticipants = commitedParticipants + 1;
        emit BuildCommited(msg.sender, _commitment);
        if (commitedParticipants == numParticipants) {
            stage = Stage.reveal;
            emit allBuildsCommitted(buildId);
        }
        return (true);
    }
    
    
    function revealBuild(bytes32 _buildId, bytes32 _buildHash, bytes32 _salt) public returns (bool) {
        require(stage == Stage.reveal, "Current build not at reveal stage");
        require(_buildId == buildId, "No pending builds against given buildId");
        require(_salt != "", "Build commitment cannot be empty");
        if (revealedParticipants > 0 && revealDeadline <= block.number) {
            emit revealDeadlinePassed(buildId);
            stage = Stage.distribute;
            distribute();
            return (true);
        }
        bool revealed = false;
        bytes32 _commitment = keccak256(abi.encodePacked(msg.sender, _buildHash, _salt));
        // First reveal try
        if (submissions[participant[msg.sender]].buildHash == ""){
            if (_commitment != submissions[participant[msg.sender]].commitment) {
                submissions[participant[msg.sender]].buildHash = "1";
                require(_commitment == submissions[participant[msg.sender]].commitment, "Invalid hash. Reveal failed. One try remaining");
            }
            else if (_commitment == submissions[participant[msg.sender]].commitment) {
                revealed = true;
            }
        }
        // second try
        else if (submissions[participant[msg.sender]].buildHash == "1") {
            if (_commitment != submissions[participant[msg.sender]].commitment) {
                revealed = false;
            }
            else if (_commitment == submissions[participant[msg.sender]].commitment) {
                revealed = true;
            }
        }
        if (revealed) {
            submissions[participant[msg.sender]].buildHash = _buildHash;
            emit BuildRevealed(buildId, msg.sender);
        }
        else {
            submissions[participant[msg.sender]].buildHash = "";
            emit BuildRevealFailed(buildId, msg.sender);
        }
        
        // If this is the first reveal, set the deadline for the submitting all reveals
        if (revealedParticipants == 0) {
            revealDeadline = block.number + RevealSpan;
            // This shouldn't be triggered normally
            require(revealDeadline >= block.number, "overflow error");
        }
        revealedParticipants = revealedParticipants + 1;
        if (revealedParticipants == numParticipants) {
            stage = Stage.distribute;
            emit allBuildsRevealed(buildId);
            distribute();
        }
        if (revealed) {
            return (true);
        } else {
            return (false);
        }
    }
    
    
    // Private Contract Methods
    function distribute() private returns (bool) {
        bytes32[] memory hashes;
        
        for (uint i=0; i < submissions.length; i++) {
            if (submissions[i].buildHash != ""){
                hashes.push(submissions[i].buildHash);
            }
        }
        (bytes32 trueBuildHash, bool success) = consensus(hashes);
        if (!success){
            emit BuildClosed(buildId, "");
            // what happens when we don't reach consensus?
        }
        else {
            for (uint i=0; i < submissions.length; i++) {
                if (submissions[i].buildHash == trueBuildHash){
                    (success,) = submissions[i].buildParticipant.call.value(participantPayout)("");
                    // require(success, "Funds transfer failed");
                    emit Payout(buildId, submissions[i].buildParticipant, participantPayout);
                    fundsTransferred = fundsTransferred + participantPayout;
                    // Cleanup participant mapping while we are here
                    participant[submissions[i].buildParticipant] = 0;
                }
            }
            // Transfer leftover funds back to payer
            if (Reward - fundsTransferred > 0) {
                (success, ) = payer.call.value(Reward - fundsTransferred)("");
                require(success, "Funds transfer failed");
            }
            emit BuildClosed(buildId, trueBuildHash);
            // Reset state
            ipfsHash = "";
            numParticipants = 0;
            currParticipants = 0;
            Reward = 0;
            RevealSpan = 0;
            participantPayout = 0;
    
            buildId = "";
            stage = Stage.register;
            fundsTransferred = 0;
            revealDeadline = 0;
            commitedParticipants = 0;
            revealedParticipants = 0;
            delete submissions;
            payer = 0;
        }
    }

    
    function consensus(bytes32[] memory _hashes) private returns (bytes32, bool) {
        // There is atleast one revealed hash in the list.
        if (_hashes.length == 1) {
            return (_hashes[0], false);
        }
        mapping (bytes32 => uint) storage occurences;
        uint maxOccur = 0;
        uint majorityHash = "";
        for (uint i=0; i < _hashes.length; i++) {
            occurences[_hashes[i]] = occurences[_hashes[i]] + 1;
            if (occurences[_hashes[i]] > maxOccur) {
                maxOccur = occurences[_hashes[i]];
                majorityHash = _hashes[i];
            }
        }
        // Applying [N/2] + 1 quorum rule. Simple majority.
        if (maxOccur >= (_hashes.length/2 + 1)) {
            return (majorityHash, true);
        } else {
            // quorum failed
            return (majorityHash, false);
        }
    }
}
