// SPDX-License-Identifier: SimPL-2.0
pragma solidity >= 0.4.25 < 0.8.5;

contract FlowOracle {
    address public oracleAddress;
    address CEO;
    uint public updateTime;
    uint WhitelistNumber;
    mapping(uint => VideoInfo) Videos;
    mapping(address => bool) Whitelist;
    event FlowUpdate(string videoname,string videosource,uint webindex,uint newupdate,uint flow,uint subflow);
    
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
        uint sublastflow;
        uint subnewflow;
    }
    function updateOracle(address _neworacleaddress) public view{
        require(msg.sender == CEO);
        oracleAddress == _neworacleaddress;
    }
    function createInfo(uint _webindex,string memory _videoname,string memory _videosource,address _videowner) external onlyoracleAddress{
        require(Videos[_webindex].ifcreate == false);
        Videos[_webindex].ifcreate = true;
        Videos[_webindex].videoname = _videoname;
        Videos[_webindex].videosource = _videosource;
        Videos[_webindex].videowner = _videowner;
        Whitelist[_videowner] = true;
    }
    function updateFlow (uint _webindex,uint _videoflow,uint _subflow) external onlyoracleAddress {
        require(block.timestamp >= Videos[_webindex].lastupdate + updateTime);
        Videos[_webindex].lastflow = Videos[_webindex].newflow;
        Videos[_webindex].newflow = _videoflow;
        Videos[_webindex].sublastflow = Videos[_webindex].subnewflow;
        Videos[_webindex].subnewflow = _subflow;
        Videos[_webindex].lastupdate = block.timestamp;
        emit FlowUpdate(Videos[_webindex].videoname,Videos[_webindex].videosource,_webindex,Videos[_webindex].lastupdate,Videos[_webindex].newflow,Videos[_webindex].subnewflow);
    }
    function getFlow(uint _webindex) external view returns(uint,uint,address) {
        return (Videos[_webindex].lastupdate,Videos[_webindex].newflow,Videos[_webindex].videowner);
    }
    function getSubFlow(uint _webindex)external view returns(uint,uint) {
        return (Videos[_webindex].sublastflow,Videos[_webindex].subnewflow);
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

}
