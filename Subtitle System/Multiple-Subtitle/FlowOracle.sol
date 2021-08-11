// SPDX-License-Identifier: SimPL-2.0
pragma solidity >= 0.8.0 < 0.9.0;

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

}
