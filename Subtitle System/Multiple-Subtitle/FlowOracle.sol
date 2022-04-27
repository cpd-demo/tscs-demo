// SPDX-License-Identifier: SimPL-2.0
pragma solidity >= 0.8.0;

contract FlowOracle {

    address public oracleAddress;
    address CEO;
    uint public updateTime;
    constructor(address  _oracleAddress, uint _updatetime) {
        oracleAddress = _oracleAddress;
        updateTime = _updatetime;
        CEO = msg.sender;
    }
    modifier onlyoracleAddress() {
        require(msg.sender == oracleAddress);
        _;
    }
    struct VideoInfo {
        bool ifcreate;
        string videoname;
        string videosource;
        uint webindex;
        address videowner;
        uint lastupdate;
        uint lastflow;
        uint newflow;
        mapping(string => SubtitleInfo) langToSub;
    }
    struct SubtitleInfo{
        uint sublastflow;
        uint subnewflow;
    }
    mapping(uint => VideoInfo) Videos;
    event FlowUpdate(string video_name,string video_source,uint video_index,uint new_update,uint _flow);
    uint WhitelistNumber;
    mapping(address => bool) Whitelist;
    mapping(uint => mapping(string => bool)) clearThrough;
    event addWhiteList(address _usr,uint _index);
    function updateOracle(address _neworacleaddress) public view{
        require(msg.sender == CEO);
        oracleAddress == _neworacleaddress;
    }
    function createInfo(uint video_index,string memory video_name,string memory video_source,address video_owner) external onlyoracleAddress{
        require(Videos[video_index].ifcreate == false);
        Videos[video_index].ifcreate = true;
        Videos[video_index].videoname = video_name;
        Videos[video_index].videosource = video_source;
        Videos[video_index].videowner = video_owner;
        Whitelist[video_owner] = true;
    }
    function updateFlow (uint video_index,uint _flow,string memory _language,uint sub_flow) external onlyoracleAddress {
        require(block.timestamp >= Videos[video_index].lastupdate + updateTime);
        require(Videos[video_index].ifcreate == true);
        Videos[video_index].lastflow = Videos[video_index].newflow;
        Videos[video_index].newflow = _flow;
        Videos[video_index].langToSub[_language].sublastflow = Videos[video_index].langToSub[_language].subnewflow;
        Videos[video_index].langToSub[_language].subnewflow = sub_flow;
        Videos[video_index].lastupdate = block.timestamp;
        emit FlowUpdate(Videos[video_index].videoname,Videos[video_index].videosource,video_index,Videos[video_index].lastupdate,Videos[video_index].newflow);
    }
    //普通更新.
     function updateFlowNormal(uint video_index,uint _flow) external onlyoracleAddress {
        require(block.timestamp >= Videos[video_index].lastupdate + updateTime);
        require(Videos[video_index].ifcreate == true);
        Videos[video_index].lastflow = Videos[video_index].newflow;
        Videos[video_index].newflow = _flow;
        Videos[video_index].lastupdate = block.timestamp;
        // emit FlowUpdate(Videos[video_index].videoname,Videos[video_index].videosource,video_index,Videos[video_index].lastupdate,Videos[video_index].newflow);
    }

    //使用签名更新视频播放量.
    function updateFlowBySig(bytes memory sig, uint video_index, uint flow) external returns(bytes32, address){
        require(block.timestamp >= Videos[video_index].lastupdate + updateTime);
        require(Videos[video_index].ifcreate == true);
        bytes32 message = prefixed(keccak256(abi.encodePacked(video_index, flow)));
        address exe = recoverSigner(message, sig);
        return (keccak256(abi.encodePacked(video_index, flow)), exe);
        // require(recoverSigner(message, sig) == oracleAddress, "not same");
        // Videos[video_index].lastflow = Videos[video_index].newflow;
        // Videos[video_index].newflow = flow;
        // Videos[video_index].lastupdate = block.timestamp;
    }

    function updateSubFlow(uint video_index,string memory _language,uint sub_flow) external onlyoracleAddress {
        require(Videos[video_index].ifcreate == true);
        Videos[video_index].langToSub[_language].sublastflow = Videos[video_index].langToSub[_language].subnewflow;
        Videos[video_index].langToSub[_language].subnewflow = sub_flow;
    }
    function getFlow(uint video_index) external view returns(uint,uint,address) {
        return (Videos[video_index].lastupdate,Videos[video_index].newflow,Videos[video_index].videowner);
    }
    function getSubFlow(uint video_index,string memory _language) external view returns(uint,uint) {
        return (Videos[video_index].langToSub[_language].sublastflow,Videos[video_index].langToSub[_language].subnewflow);
    }
    function addWhiteListUsr(address _usr) external onlyoracleAddress returns(bool,uint) {
        Whitelist[_usr] = true;
        WhitelistNumber++;
        return (true,WhitelistNumber);
    }
    function ifWhiteListUsr(address _usr) external view returns(bool) {
        return Whitelist[_usr];
    }
    function ifVideoOwner(uint webindex,address usr) external view returns(bool) {
        require(Videos[webindex].videowner == usr);
        return true;
    }
    /*function confirmThrough(uint video_index,string memory _simhash)external onlyoracleAddress returns(bool){
        clearThrough[video_index][_simhash] = true;
        return true;
    }*/

    // 签名.
    // 第三方方法，分离签名信息的 v r s
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(sig.length == 65);

        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v + 27, r, s);
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    /// 加入一个前缀，因为在eth_sign签名的时候会加上。
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

}
