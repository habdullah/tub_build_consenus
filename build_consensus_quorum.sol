pragma solidity ^0.4.25;

contract BuildContract {
    
    enum Stage{
        commit,
        reveal,
        distribute
    }
    /*
     * Depricated
     */
    // struct ipfsHash{
    //     bytes32 commitment,
    //     bytes32 salt,
    //     bytes32 ipfsHash
    // }

    struct buildSubmission{
        address buildParticipant;
        bytes32 commitment;
        bytes32 buildHash;
        uint participantNo;
    }
    
    
    struct build{
        Stage stage;
        // 1 indexed
        mapping (uint => buildSubmission) submissions;
        // Initialization variables
        bytes32[] ipfsHash;
        uint numParticipants;
        uint currParticipants;
        uint commitSpan;
        uint revealSpan;
        // System variables
        bytes32 buildId;
 
        uint commitDeadline;
        uint revealDeadline;
        uint commitedParticipants;
        uint revealedParticipants;
        address payer;
        bool exists;
        // 1 indexed
        mapping (address => uint) participants;
        mapping (bytes32 => uint) occurences;
    }
    
    mapping (bytes32 => build) builds;
    bytes32[] hashes;
    bytes32[] buildIds;
    
    // Events
    event BReqAccepted(address _payor, bytes32 _buildId, uint _numParticipants, uint _commitSpan, uint _revealSpan, bytes32[] hIpfs);
    event BReqRejected(address _payor, bytes32 _buildId, uint _numParticipants, uint _commitSpan, uint _revealSpan, bytes32[] hIpfs);
    //event PartcipantRegistered(address _participant, bytes32 _buildId);
    //event BuildOpened(bytes32 _buildId, bytes32 _ipfsHash, uint _numParticipants, uint _participantPayout, uint _commitDeadline, uint _revealDeadline);
    event BuildCommited(address _participant, bytes32 _commitment);
    event allBuildsCommitted(bytes32 _buildId);
    event BuildRevealed(bytes32 _buildId, address _participant);
    event BuildRevealFailed(bytes32 _buildId, bytes32 _intern_commitment, bytes32 _calc_commitment, address _participant);
    event allBuildsRevealed(bytes32 _buildId);
    event commitDeadlinePassed(bytes32 _buildId);
    event revealDeadlinePassed(bytes32 _buildId);
    event Payout(bytes32 _buildId, address _participant, uint _participantPayout);
    event consensusFailed(bytes32 _buildId, bytes32[] hashes);
    event BuildClosed(bytes32 _buildId, bytes32 _truebuildHash);
    
    function getBytes32ArrayForInput() pure public returns (bytes32[2] memory b32Arr) {
    b32Arr = [bytes32("QmbPtNLVtjfkcG99ZbTc3esyg"), bytes32("ZEPZFnpWTjnfKoMPXCqeA")];
    }
    function getcommitment(bytes32 hash, bytes32 salt) pure public returns (bytes32 _commitment) {
        _commitment = keccak256(abi.encode(hash, salt));
    }
    // Public Contract Methods
    function addBReq(bytes32[] memory _ipfshash, uint _numP, uint _commitSpan, uint _revealSpan) public returns (bool) {
        require(_ipfshash.length > 0, "ipfsHash cannot be empty");
        require(_commitSpan > 0 && _commitSpan < 1000000, "commitSpan cannot be 0 or too long");
        require(_revealSpan > 0 && _revealSpan < 1000000, "revealSpan cannot be 0 or too long");
        require(_numP >= 3, "Atleast 3 participants required for consensus");
        //require(_commitDeadline > 10 && _revealDeadline > 10, "Commit and reveal deadlines must be greater than 0");
        bytes32 _buildId = keccak256(abi.encode(_ipfshash, _numP, _commitSpan, _revealSpan));
        if (builds[_buildId].exists){
            emit BReqRejected(msg.sender, _buildId, _numP, _commitSpan, _revealSpan, _ipfshash);
        }
        
        // Create build object
        build storage b = builds[_buildId];
        b.stage =  Stage.commit;
        b.ipfsHash = _ipfshash;
        b.numParticipants = _numP;
        b.currParticipants = 0;
        b.commitSpan = _commitSpan;
        b.revealSpan = _revealSpan;
        b.buildId = _buildId;
        b.commitDeadline = 0;
        b.revealDeadline = 0;
        b.commitedParticipants = 0;
        b.revealedParticipants = 0;
        b.payer = msg.sender;
        b.exists = true;
        
        buildIds.push(_buildId);

        emit BReqAccepted(msg.sender, _buildId, _numP, _commitSpan, _revealSpan, _ipfshash);
        //emit BuildOpened(_buildId, _ipfshash, _numP, _commitDeadline, _revealDeadline);
        return (true);
    }
    
    
    function getBReq(bytes32 _buildId) public view returns (address, bytes32, uint, uint, uint, bytes32[]) {
        require(_buildId != "" && builds[_buildId].exists, "No active builds found against supplied buildId");
        return (builds[_buildId].payer, _buildId, builds[_buildId].numParticipants, builds[_buildId].commitSpan, builds[_buildId].revealSpan, builds[_buildId].ipfsHash);
    }
    
    function getPending() public view returns (bytes32) {
        if (buildIds.length != 0){
            return buildIds[0];
        } else {
            return bytes32(12345);
        }
    }
    
    /*
     * Participant registration removed in last revision in permissioned blockchain
     */
    // function regParticipant(bytes32 _buildId) public returns (bool) {
    //     require(stage == Stage.register && _buildId != "", "No build request pending");
    //     require(currParticipants < numParticipants, "participants full");
    //     require(_buildId == buildId, "No build pending against this bId");
        
    //     buildSubmission[currParticipants] = buildSubmission(msg.sender, "", "");
    //     participant[msg.sender] = currParticipants;
    //     currParticipants = currParticipants + 1;
    //     emit PartcipantRegistered(buildSubmission[currParticipants].buildParticipant, buildId);
        
    //     // Move to next stage if participants full
    //     if (currParticipants == numParticipants) {
    //         stage = Stage.commit;
    //         emit BuildOpened(buildId, ipfsHash);
    //     }
    //     return (true);
    // }
    
    /*
     * Participant information increases attack vector. removed in last revision in permissioned blockchain
     */
    // function getParticipants(bytes32 _buildId) public returns (uint, uint , buildSubmission[] memory) {
    //     require(_buildId == buildId, "No build pending against bId");
    //     return (currParticipants, numParticipants, submissions);
    // }
    
    
    function getIpfsHash(bytes32 _buildId) public view returns (bytes32[] memory) {
        require(_buildId != "" && builds[_buildId].exists, "No active builds found against supplied buildId");
        return (builds[_buildId].ipfsHash);
    }
    
    
    
    function commitBuild(bytes32 _buildId, bytes32 _commitment) public returns (bool) {
        require(builds[_buildId].stage == Stage.commit, "Current build not at commit stage");
        require(_commitment != "", "Build commitment cannot be empty");
        require(_buildId != "" && builds[_buildId].exists, "No active builds found against supplied buildId");
        // Check if commit deadline passed
        if (builds[_buildId].commitedParticipants > 0 && builds[_buildId].commitDeadline <= block.number) {
            emit commitDeadlinePassed(_buildId);
            builds[_buildId].stage = Stage.reveal;
            return (true);
        }
        require(builds[_buildId].currParticipants < builds[_buildId].numParticipants, "participants full");
        
        // Don't know if this works
        require(builds[_buildId].submissions[builds[_buildId].participants[msg.sender]].commitment == "", "Participant already commited build hash");
        
        // currParticipants =0 for no participants
        // First register participant
        builds[_buildId].currParticipants = builds[_buildId].currParticipants + 1;
        builds[_buildId].participants[msg.sender] = builds[_buildId].currParticipants;
        
        // Save submission
        builds[_buildId].submissions[builds[_buildId].currParticipants] = buildSubmission({buildParticipant: msg.sender, commitment: _commitment, buildHash: "", participantNo: builds[_buildId].currParticipants});
        builds[_buildId].commitedParticipants = builds[_buildId].commitedParticipants + 1;
        emit BuildCommited(msg.sender, _commitment);
        
        // If this is the first commit, set the deadline for committing all the builds
        if (builds[_buildId].commitedParticipants == 1) {
            builds[_buildId].commitDeadline = block.number + builds[_buildId].commitSpan;
            // This shouldn't be triggered normally
            require(builds[_buildId].commitDeadline >= block.number, "overflow error");
        }
        
        // Move to next stage if participants full
        if (builds[_buildId].currParticipants == builds[_buildId].numParticipants) {
            builds[_buildId].stage = Stage.reveal;
            emit allBuildsCommitted(_buildId);
            // Start reveal timer
            return (true);
        }
        return (true);
    }
    

    function revealBuild(bytes32 _buildId, bytes32 _buildHash, bytes32 _salt) public returns (bool) {
        require(_buildId != "" && builds[_buildId].exists, "No active builds found against supplied buildId");
        require((builds[_buildId].stage == Stage.reveal) ||  (builds[_buildId].stage == Stage.commit && builds[_buildId].commitDeadline <= block.number), "Current build not at reveal stage");
        require(_salt != "", "Build salt (Blinding factor cannot be empty)");
        require(builds[_buildId].participants[msg.sender] != 0, "Not an authorized Participant");
        require(builds[_buildId].submissions[builds[_buildId].participants[msg.sender]].buildHash == "", "Participant already revealed build hash");
        // Check if reveal deadline passed
        if (builds[_buildId].revealedParticipants > 0 && builds[_buildId].revealDeadline <= block.number) {
            emit revealDeadlinePassed(_buildId);
            builds[_buildId].stage = Stage.distribute;
            return (true);
        }
        bool revealed = false;
        bytes32 _commitment = keccak256(abi.encodePacked(_buildHash, _salt));
        if (builds[_buildId].submissions[builds[_buildId].participants[msg.sender]].commitment == _commitment) {
            revealed = true;
            emit BuildRevealed(_buildId, msg.sender);
            builds[_buildId].submissions[builds[_buildId].participants[msg.sender]].buildHash = _buildHash;
        } else {
            revealed = false;
            emit BuildRevealFailed(_buildId, builds[_buildId].submissions[builds[_buildId].participants[msg.sender]].commitment, _commitment, msg.sender);
            builds[_buildId].submissions[builds[_buildId].participants[msg.sender]].buildHash = "failed";
        }
        
        builds[_buildId].revealedParticipants = builds[_buildId].revealedParticipants + 1;
        // If this is the first reveal, set the deadline for the submitting all reveals
        if (builds[_buildId].revealedParticipants == 1) {
            builds[_buildId].revealDeadline = block.number + builds[_buildId].revealSpan;
            // This shouldn't be triggered normally
            require(builds[_buildId].revealDeadline >= block.number, "overflow error");
        }
        if (builds[_buildId].revealedParticipants == builds[_buildId].numParticipants) {
            builds[_buildId].stage = Stage.distribute;
            emit allBuildsRevealed(_buildId);
            distribute(_buildId);
        }
        if (revealed) {
            return (true);
        } else {
            return (false);
        }
    }
    
    
    // Private Contract Methods
    function distribute(bytes32 _buildId) private returns (bool) {
        
        for (uint i=1; i < builds[_buildId].currParticipants; i++) {
            if (builds[_buildId].submissions[i].buildHash != "" && builds[_buildId].submissions[i].buildHash != "failed"){
                hashes.push(builds[_buildId].submissions[i].buildHash);
            }
        }
        (bytes32 trueBuildHash, bool success) = consensus(hashes, _buildId);
        if (!success){
            // emit consensusFailed(_buildId, hashes);
            emit BuildClosed(_buildId, "");
            builds[_buildId].exists = false;
            delete builds[_buildId];
            delete hashes;
            return(false);
            // what happens when we don't reach consensus?
        }
        else {
            /*
             * No payout in permissioned blockchain
             */
            // for (uint i=1; i < builds[_buildId].currParticipants; i++) {
            //     if (builds[_buildId].submissions[i].buildHash == trueBuildHash){
            //         (success,) = builds[_buildId].submissions[i].buildParticipant.call{value:builds[_buildId].participantPayout}("");
            //         // require(success, "Funds transfer failed");
            //         emit Payout(_buildId, builds[_buildId].submissions[i].buildParticipant, builds[_buildId].participantPayout);
            //         builds[_buildId].fundsTransferred = builds[_buildId].fundsTransferred + builds[_buildId].participantPayout;
            //     }
            // }
            emit BuildClosed(_buildId, trueBuildHash);
            builds[_buildId].exists = false;
            delete builds[_buildId];
            delete hashes;
            return(true);
        }
    }
    
    function consensus(bytes32[] memory _hashes, bytes32 _buildId) private returns (bytes32, bool) {
        emit consensusFailed(_buildId, _hashes);
        // There is atleast one revealed hash in the list.
        if (_hashes.length == 1) {
            return (_hashes[0], false);
        }
        
        uint maxOccur = 0;
        bytes32 majorityHash = "";
        for (uint i=0; i < _hashes.length; i++) {
            builds[_buildId].occurences[_hashes[i]] = builds[_buildId].occurences[_hashes[i]] + 1;
            if (builds[_buildId].occurences[_hashes[i]] > maxOccur) {
                maxOccur = builds[_buildId].occurences[_hashes[i]];
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
