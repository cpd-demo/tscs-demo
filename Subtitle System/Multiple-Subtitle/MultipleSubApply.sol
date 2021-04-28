// SPDX-License-Identifier: SimPL-2.0
pragma solidity >= 0.4.25 < 0.8.5;
pragma experimental ABIEncoderV2;

import "./ERC721/Address.sol";
import "./ERC721/ERC165.sol";
import "./ERC721/IERC721Receiver.sol";

interface FlowOracleInterface {
    function ifWhiteListUsr(address usr) external view returns(bool);
    function ifVideoOwner(uint webindex,address usr) external view returns(bool);
}

contract config  {
    using Address for address;
    //合约默认属性.
    address CEO;
    uint applyVideosNumber;
    uint applyNumber;
    uint submitSubNumber;
    event applysubtitle(address owner,uint videoindex,string videoname,string language,uint paytype,uint paynumber);
    event subtitlesubmit(uint videoindex,string videoname,string language);
    event confirm(uint webidnex,string videoname,string language,uint subindex);
    event DeleteSub(uint _webindex,uint index, string _ipfsaddress, string _subtitlehash,address[] _stepaddress);
    event DeleteSubByOwner(uint _webindex,uint index, string _ipfsaddress, string _subtitlehash);
    //ERC-721事件.
    event Transfer(address indexed _from,address indexed _to,uint indexed _tokenId);
    event Approval(address indexed _owner,address indexed _approved,uint indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    string[] PayType;//所有支付类型.
    //address[] Arbiter;
    
    constructor() {
        
        //CEO可以设置支付类型
        CEO = msg.sender;
        PayType.push("0:Share payment.");
        PayType.push("1:One time payment.");
    }
    //当用户进行申请和上传操作时才会创建此结构.
    struct Usr {
        bool ifcreate;
        uint applypoints;
        uint submitpoints;
        uint creditpoints;
    }
    //字幕和视频结构 .
    struct Video {
        uint WebIndex;
        uint ApplyNums;
        string VideoName;
        string VideoSource;
        address VideoOwner;
        string[] ApplyLa;
        mapping(string => subVideo) Applys;    
    }
    struct subVideo{
        uint WebIndex;//applyindex与video结构映射.
        uint ApplyIndex;
        string ApplyLanguage;
        uint ApplyTime;
        uint PayType;
        uint PayNumber;
        
        bool IfSucess;
        uint SuccessSubId;
        address SubOwner;
        string SucSubaddress;
        uint SubtitleNums;
        uint[] VideoSubtitles;//方便单个视频页面内的相关操作,在字幕被确定采纳后，实则可以清空（使用delete删除，Subtitle[] VideoSubtitles，但只是引用，我觉得没必要删除处理）.
    }
    struct Subtitle {
        uint subtitleindex;
        uint subvideoindex;
        string videoname;
        uint webindex;
        address subtitleowner;
        
        string language;
        string ipfsaddress;//如何防止用户在本地删除字幕文件，视频作者主动存储（去中心化）或者视频网站自动下载备份（中心化）.
        string subtitlehash;
        
        uint top;
        address[] topaddress;//若被采用，对这部分用户进行分成奖励，其若也支持交易，很麻烦，（需要设置用户结构）.
        uint step;
        address[] stepaddress;
        bool iftaking;
        uint lastupdated;
    }
    mapping(uint => subVideo) subvideos;//applyindex 和 subvideo
    mapping(uint => bool) videocreate;//根据视频唯一标识webindex判断视频是否已经申请过.
    mapping(address => Usr) User;//用户结构设计，主要是用来之后用户等级及其对应特权功能的奖励设计，以及对恶意用户的惩罚设计.
    mapping(uint => Video) videos;//申请字幕视频总数.
    mapping(uint => Subtitle) subtitles;//提交字幕总数.
    mapping(address => uint) userapplys;//某用户上传视频总数.
    mapping(address => uint) usersubmits;//balanceOf，某用户提交字幕总数.
    mapping(uint => address) subtitleToApproved;//将某字幕授权给某地址操作.
    mapping(address => mapping(uint => bool)) userforsubvote;//限制对某个字幕只能评价一次.
    mapping(address => mapping(uint => mapping(string => bool))) onlyvoteone;//限制对某个视频只能投一个字幕.
    mapping(uint => mapping(string => bool)) ifapply;//判断webindex该视频号是否已经申请过这种语言.
    mapping(address => mapping(address => bool)) ownerToOperators;
    //mapping(address => bool) administrators;
    
    //用户结构未设置 ，可以设置升级功能，即用户上传一定字幕并通过后提升等级，并可获得一定特权.
    modifier onlyCEO() {
        require(msg.sender == CEO);
        _;
    }
    //防止恶意字幕上传，视频作者可将恶意字幕置空，逻辑上考虑作者恶意行为的可能性，发了钱发布是为了获得字幕，如果真的没问题不会恶意删除，另外对某人字幕不采用或指定某人字幕的可能性都很低.
    modifier onlyvideoowner (uint _webindex,string memory _applylanguage) {
        require(videos[_webindex].VideoOwner == msg.sender);
        require(videos[_webindex].Applys[_applylanguage].IfSucess == false);
        _;
    }
    //ERC-721标准修改器.
    modifier canOperate(uint _subtitleindex) {
        address tokenowner = subtitles[_subtitleindex].subtitleowner;
        require(tokenowner == msg.sender || ownerToOperators[tokenowner][msg.sender]);
        _;
    }
    modifier canTransfer(uint _subtitleindex) {
        address subtitleowner = subtitles[_subtitleindex].subtitleowner;
        require(subtitleowner == msg.sender ||  subtitleToApproved[_subtitleindex] == msg.sender || ownerToOperators[subtitleowner][msg.sender] == true);
        _;
    }
    modifier validNFToken(uint _subtitleindex) {
        require(subtitles[_subtitleindex].subtitleowner != address(0));
        _;
    }

    //交易功能
    function _transfer(address _to, uint256 _tokenId) internal {
        require(_to != address(0));
        address _from = subtitles[_tokenId].subtitleowner;
        usersubmits[_to]++;
        usersubmits[_from]--;
        subtitles[_tokenId].subtitleowner = _to;
        //当用户在结算日前进行字幕交易时，一部分损失将有_from承担.
        if (subtitles[_tokenId].iftaking == true) {
            subvideos[subtitles[_tokenId].subvideoindex].SubOwner = _to;
        }
        delete subtitleToApproved[_tokenId];
        emit Transfer(_from, _to, _tokenId);
    }
    //ERC-721标准相关.
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
    function _safeTransferFrom(address _from,address _to,uint _tokenId,bytes memory _data) internal canTransfer(_tokenId) validNFToken(_tokenId) {
        address tokenowner = subtitles[_tokenId].subtitleowner;
        require(tokenowner == _from);
        require(_to != address(0));
        _transfer(_to, _tokenId);
        require(_checkOnERC721Received(_from, _to, _tokenId, _data),"ERC721: transfer to non ERC721Receiver implementer");
    }
}
contract Subtitle_ERC721 is config{
    function approve(address _to,uint _subtitleindex)external canOperate(_subtitleindex) validNFToken(_subtitleindex) {
        require(subtitles[_subtitleindex].subtitleowner != _to);
        subtitleToApproved[_subtitleindex] = _to;
        emit Approval(msg.sender, _to, _subtitleindex);
    }
    function getApproved(uint _subtitleindex) external view validNFToken(_subtitleindex) returns(address){
        return subtitleToApproved[_subtitleindex];
    }
    function setApprovalForAll(address _operator, bool _approved) external {
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }
    function isApprovedForAll(address _owner, address _operator) external view returns(bool){
        return ownerToOperators[_owner][_operator];
    }
    function transferFrom (address _from,address _to,uint _subtitleindex)external canTransfer(_subtitleindex) validNFToken(_subtitleindex){//transferSubtitle
        address tokenowner = subtitles[_subtitleindex].subtitleowner;
        require(tokenowner == _from);
        _transfer(_to,_subtitleindex);
    }
    function safeTransferFrom(address _from,address _to,uint _tokenId,bytes calldata _data) external {
        _safeTransferFrom(_from,_to,_tokenId,_data);
    }
    function safeTransferFrom(address _from,address _to,uint _tokenId) external {
        _safeTransferFrom(_from,_to,_tokenId,"");
        
    }
    //返回指定用户上传过的字幕序号.
    function balanceOf(address _owner) external view returns(uint,uint[] memory) {//subtitlesOfOwner
        uint subtitlecount = usersubmits[_owner];
        uint[] memory result = new uint[](subtitlecount);
        uint totalsubtitles = submitSubNumber;
        uint resultIndex = 0;
        uint subtitleid;
        for(subtitleid = 1;subtitleid<=totalsubtitles;subtitleid++){
            if(subtitles[subtitleid].subtitleowner == _owner){
            result[resultIndex] = subtitleid;
            resultIndex++;
            }
        }
        return (subtitlecount,result);
    }
    function ownerOf(uint _subtitleindex)external view returns(address _owner) {
        _owner = subtitles[_subtitleindex].subtitleowner;
        require(_owner != address(0));
    }
    //思想是用来给想要购买该字幕Token的人来使用.
    function getTokenInfo(uint _subtitleindex) public view returns(uint,address,string memory,uint,uint,bool){
         //对于投资人而言，只要该视频尚未字幕，便可对其上传的字幕进行购买，因为可以通过自己的手段来让该字幕被确认，虽然我们的系统应极力抵制这种做法，但是在实际上，投资人也必将优先选择合适的（至少不会是错的很离谱的）字幕，我们设计的系统也有强调字幕的质量，但更多时候（即使质量一般）上传速度往往更重要，所以以此来换取更多的金融中的操作和活跃度是值得的。
        require((videos[subtitles[_subtitleindex].webindex].Applys[subtitles[_subtitleindex].language].IfSucess == false && subtitles[_subtitleindex].iftaking == false) || (videos[subtitles[_subtitleindex].webindex].Applys[subtitles[_subtitleindex].language].IfSucess == true && subtitles[_subtitleindex].iftaking == true));
        return (subtitles[_subtitleindex].webindex,subtitles[_subtitleindex].subtitleowner,subtitles[_subtitleindex].language,videos[subtitles[_subtitleindex].webindex].Applys[subtitles[_subtitleindex].language].PayType,videos[subtitles[_subtitleindex].webindex].Applys[subtitles[_subtitleindex].language].PayNumber,subtitles[_subtitleindex].iftaking);
    } 
}

contract Subtitle_Function is Subtitle_ERC721 {
    constructor(address _oracleaddr) {//address[] memory arbiter
        Oracle = FlowOracleInterface(_oracleaddr); 
        //Arbiter = arbiter;
        //for (uint i = 0; i < Arbiter.length; i++) {
        //    administrators[Arbiter[i]] = true;
        //}
    }
    FlowOracleInterface Oracle;
    modifier onlyWhiteListUsr(address _usr) {
        require(Oracle.ifWhiteListUsr(_usr));
        _;
    }
    //modifier ifAdministrators(address _usr) {
    //    require(_usr == CEO || administrators[_usr] == true);
    //    _;
    //}
    function VideoApply (uint _webindex,string memory _videoname,string memory _videosource,string memory _language,uint _paytype,uint _paynumber) public returns(uint){
        require(ifapply[_webindex][_language] == false);
        require(Oracle.ifVideoOwner(_webindex,msg.sender));
        if(User[msg.sender].ifcreate == false) {
            User[msg.sender].applypoints = 100;
            User[msg.sender].submitpoints = 100;
            User[msg.sender].creditpoints = 100;
            User[msg.sender].ifcreate = true;
        }
        if(videocreate[_webindex] == false) {
            applyVideosNumber++; 
            videos[_webindex].WebIndex = _webindex;
            videos[_webindex].VideoName = _videoname;
            videos[_webindex].VideoOwner = msg.sender;
            videos[_webindex].VideoSource = _videosource;
            videocreate[_webindex] = true;
        }
        applyNumber++;
        videos[_webindex].ApplyNums++;
        subvideos[applyNumber].WebIndex= _webindex;
        subvideos[applyNumber].ApplyIndex= applyNumber; 
        subvideos[applyNumber].ApplyLanguage = _language;
        subvideos[applyNumber].PayType = _paytype;
        subvideos[applyNumber].PayNumber = _paynumber;
        subvideos[applyNumber].ApplyTime = block.timestamp;
        subvideos[applyNumber].IfSucess = false;
     
        videos[_webindex].Applys[_language] = subvideos[applyNumber];
        
        userapplys[msg.sender]++;
        User[msg.sender].applypoints += 1;
        videos[_webindex].ApplyLa.push(_language);
        ifapply[_webindex][_language] == true;
        emit applysubtitle(msg.sender,_webindex,_videoname,_language,_paytype,_paynumber);
        return applyNumber;
        
    }
    
    function SubtitleSubmit(string memory _videoname,uint _webindex,string memory _language,string memory _ipfsaddress,string memory _subtitlehash) public  returns(uint){
        require(videos[_webindex].Applys[_language].IfSucess == false);
        require(User[msg.sender].creditpoints >= 60);//对于恶意用户禁止上传.
        require(keccak256(abi.encodePacked(videos[_webindex].VideoName)) == keccak256(abi.encodePacked(_videoname)) && keccak256(abi.encodePacked(videos[_webindex].Applys[_language].ApplyLanguage)) == keccak256(abi.encodePacked(_language))); //上传条件判断视频号、语言等是否一一对应 .
        if(User[msg.sender].ifcreate == false) {
            User[msg.sender].applypoints = 100;
            User[msg.sender].submitpoints = 100;
            User[msg.sender].creditpoints = 100;
            User[msg.sender].ifcreate = true;
        }
        submitSubNumber++;
        videos[_webindex].Applys[_language].SubtitleNums++;
        subtitles[submitSubNumber].videoname = _videoname;
        subtitles[submitSubNumber].webindex = _webindex;
        subtitles[submitSubNumber].lastupdated = block.timestamp;
        subtitles[submitSubNumber].subtitleowner = msg.sender;
        subtitles[submitSubNumber].language = _language;
        subtitles[submitSubNumber].ipfsaddress = _ipfsaddress;
        subtitles[submitSubNumber].subtitlehash = _subtitlehash;
        subtitles[submitSubNumber].iftaking = false;    
        subtitles[submitSubNumber].subtitleindex = submitSubNumber;
        videos[_webindex].Applys[_language].VideoSubtitles.push(submitSubNumber);//引用传递.
        usersubmits[msg.sender]++;
        User[msg.sender].submitpoints += 1;
        emit subtitlesubmit(_webindex,_videoname,_language);
        return submitSubNumber;
        
    }
    //编辑功能
    function editVideoInfo (uint _webindex,string memory _language,uint _paytype,uint _paynumber) public onlyvideoowner(_webindex,_language)  {
        require(videos[_webindex].Applys[_language].IfSucess == false);
        videos[_webindex].Applys[_language].PayType = _paytype;
        videos[_webindex].Applys[_language].PayNumber = _paynumber;
    }
    
    function editSubtitleInfo (uint _subtitleindex,string memory _langugae,string memory _ipfsaddress,string memory _subtitlehash)public canOperate(_subtitleindex) {
        require(subtitles[_subtitleindex].iftaking == false);
        subtitles[_subtitleindex].lastupdated = block.timestamp;
        subtitles[_subtitleindex].language = _langugae;
        subtitles[_subtitleindex].ipfsaddress = _ipfsaddress;
        subtitles[_subtitleindex].subtitlehash = _subtitlehash;
    }
    //添加支付类型
    function addPayType(string memory _newpaytype) public onlyCEO {
        PayType.push(_newpaytype);

    }
    //function editUsrInfo(address _usr,uint _newcredpoints)public ifAdministrators(msg.sender) returns(bool) {
    //    User[_usr].creditpoints = _newcredpoints;
    //    return true;
    //}
    //只有视频作者或者字幕作者可以查看该字幕信息，方便两者随时查看信息以便修改或其它操作.
    function SubtitleInfo(uint _subtitleindex) public view returns(uint,address,string memory,bool,uint,uint) {
        require(msg.sender == subtitles[_subtitleindex].subtitleowner || msg.sender == videos[subtitles[_subtitleindex].webindex].VideoOwner);
        return (subtitles[_subtitleindex].webindex,subtitles[_subtitleindex].subtitleowner,subtitles[_subtitleindex].language,subtitles[_subtitleindex].iftaking,videos[subtitles[_subtitleindex].webindex].Applys[subtitles[_subtitleindex].language].PayType,videos[subtitles[_subtitleindex].webindex].Applys[subtitles[_subtitleindex].language].PayNumber);
    }
    //提供给字幕工作者的功能.
    //将未采用字幕的视频且符合输入语言的视频号输出，用于字幕提供者查询.
    function findapply(string calldata _language)external view returns(uint[] memory) {
        uint[] memory result = new uint[](applyNumber);
        uint totalapplys = applyNumber;
        uint subvideoindex = 0;
        uint subvideoid;
        for(subvideoid=1;subvideoid<=totalapplys;subvideoid++){
            if(subvideos[subvideoid].IfSucess==false && keccak256(abi.encodePacked(subvideos[subvideoid].ApplyLanguage)) == keccak256(abi.encodePacked(_language))){
                result[subvideoindex] = subvideos[subvideoid].WebIndex;
                subvideoindex++;
            }
        }
        return result;   
    }
    //用来向意图为该视频提交字幕或为视频拥有者进行相关信息查询提供的接口.
    function getVideoInfo (uint  _webindex,string memory _language) public view returns(string memory,uint,uint) {
        require(videos[_webindex].Applys[_language].IfSucess == false || msg.sender == videos[_webindex].VideoOwner);
        return (videos[_webindex].VideoName,  videos[_webindex].Applys[_language].PayType, videos[_webindex].Applys[_language].PayNumber);
    }
    //外部调用接口功能,专用来服务reward合约.
    //用来查询该视频是否提交申请以及申请语种.
    function checkApply(uint _webindex) external view returns(bool) {
        uint len = videos[_webindex].ApplyNums;
        if(len > 0) {
            return true;
        }else {
            return false;
        }  
    }
    function getLanguage(uint _webindex) external view returns(uint,string[]memory) {
        uint len = videos[_webindex].ApplyNums;
        require(len > 0);
        string[] memory result = new string[](len);
            uint resultid;
            for (resultid=0;resultid<len;resultid++){
                result[resultid] = videos[_webindex].ApplyLa[resultid];
            }
            return (len,result);
    }
    //查看该视频是否成功获得某语种的字幕.
    function checkApplyLa(uint _webindex,string memory _language)external view returns(bool) {
        bool ifsuccess;
        ifsuccess = videos[_webindex].Applys[_language].IfSucess;
        return (ifsuccess);
    }
    //返回支付类型、支付金额、字幕作者和反馈人的地址.
    function returnRewardInfo(uint _webindex,string memory _language)external view returns(uint,uint,address,address[] memory) {
        require(videos[_webindex].Applys[_language].IfSucess == true);
        uint len = subtitles[videos[_webindex].Applys[_language].VideoSubtitles[videos[_webindex].Applys[_language].SuccessSubId]].top;
        address[] memory _fbaddress = new address[](len);
        uint addid;
        for (addid=0;addid<len;addid++){
            _fbaddress[addid] = subtitles[videos[_webindex].Applys[_language].VideoSubtitles[videos[_webindex].Applys[_language].SuccessSubId]].topaddress[addid];
        }
        return (videos[_webindex].Applys[_language].PayType,videos[_webindex].Applys[_language].PayNumber,videos[_webindex].Applys[_language].SubOwner,_fbaddress);
    }
    //服务于为外部视频平台的接口.
    //用于外部视频平台获取该视频所有上传字幕.
    function subtitlesOfVideo(uint _webindex,string memory _language) external view returns(string[] memory) {
        uint subnum = videos[_webindex].Applys[_language].SubtitleNums;
        string[] memory result = new string[](subnum);
        uint subindex;
        for(subindex=0;subindex<subnum;subindex++){
            result[subindex] = subtitles[videos[_webindex].Applys[_language].VideoSubtitles[subindex]].ipfsaddress;
        }
        return result;
    }
    //专用于外部视频平台获取被成功采用的字幕IPFS哈希（地址）.  
    function Subtitleinterface(uint _webindex,string memory _language) external view returns(string memory) {
        require(videos[_webindex].Applys[_language].IfSucess == true );
        return videos[_webindex].Applys[_language].SucSubaddress;
    }
    //专用于外部平台获取simhash比较.
    function getSimhash(uint _webindex,string memory _language) external view returns(uint,string[] memory){
        uint num = videos[_webindex].Applys[_language].SubtitleNums;
        string[] memory simhashs = new string[](num);
        for(uint i=0;i<num;i++){
            simhashs[i] = subtitles[videos[_webindex].Applys[_language].VideoSubtitles[i]].subtitlehash;
        }
        return (num,simhashs);
    }
    //为用户提供查询系统可公开信息的功能.
    //获得系统数目信息.
    function getTotalVideos() external view returns(uint) {
        return applyVideosNumber;
    }
    function getTotalApplus() external view returns(uint) {
        return applyNumber;
    }
    function getTotalSubtitles() external view returns(uint) {
        return submitSubNumber;
    }
    //返回支持的支付方式.
    function getPayType() external view returns(string[] memory) {
        uint typenum = PayType.length;
        string[] memory result = new string[](typenum);
        uint typeindex;
        for(typeindex=0;typeindex<typenum;typeindex++){
            result[typeindex] = PayType[typeindex];
        }
        return result;
    }
    //返回指定用户申请过的视频序号.
    function videosOfOwner(address _owner) external view returns(uint[] memory) {
        uint videoscount = userapplys[_owner];
        uint[] memory result = new uint[](videoscount);
        uint totalvideos = applyVideosNumber;
        uint resultIndex = 0;
        uint videoid;
        for(videoid= 1;videoid<=totalvideos;videoid++){
            if(videos[videoid].VideoOwner == _owner) {
            result[resultIndex] = videoid;
            resultIndex++;
            }
        }
        return result;
    }
    //返回某用户信息，查询需要一定的条件,CEO或信誉度优秀用户.
    function checkUsrInfo(address _usr) external view returns(uint,uint,uint) {
        require(msg.sender == CEO || User[msg.sender].creditpoints > 200);
        return (User[_usr].applypoints,User[_usr].submitpoints,User[_usr].creditpoints);
    }
    //字幕操作
    //视频作者有权删除（恶意）字幕.
    function VoDecSub (uint _webindex,string memory _language,uint _subtitleindex) external onlyvideoowner(_webindex,_language) returns(bool) {
         uint index = videos[_webindex].Applys[_language].VideoSubtitles[_subtitleindex];
         require(subtitles[index].iftaking == false);
         require(subtitles[index].webindex == _webindex);
         emit DeleteSubByOwner(_webindex, index, subtitles[index].ipfsaddress, subtitles[index].subtitlehash);//公示以便仲裁使用.
         delete subtitles[index];
         return true;
    }
    //只能对某个视频下的其中一个字幕作出点赞操作，但可以对多个字幕进行点踩操作，另外对同一字幕只能操作（赞或踩）一次且不能修改，
    function Top (uint _webindex,string memory _language,uint _subtitleindex) external onlyWhiteListUsr(msg.sender) returns(bool){
        uint index = videos[_webindex].Applys[_language].VideoSubtitles[_subtitleindex];
        if(User[msg.sender].ifcreate == false) {
            User[msg.sender].applypoints = 100;
            User[msg.sender].submitpoints = 100;
            User[msg.sender].creditpoints = 100;
            User[msg.sender].ifcreate = true;
        }
        require(User[msg.sender].creditpoints >= 60);
        require(onlyvoteone[msg.sender][_webindex][_language] == false);//只能对视频的某一个字幕投票.
        require(userforsubvote[msg.sender][index] == false);//只能对某字幕投一次且不能更改，如何解决用户误触的问题.
        require(videos[_webindex].Applys[_language].IfSucess == false);//如果视频已经采纳了某字幕，则停止其踩赞功能.
        subtitles[index].top++;//videos[_videoindex].VideoSubtitles[_subtitleindex].top++
        subtitles[index].topaddress.push(msg.sender);
        if (subtitles[index].iftaking == false && videos[_webindex].Applys[_language].IfSucess == false) {
            //临时字幕确定函数，确定采用该字幕后，向字幕内的topaddress[]中的地址按照先后顺序发送奖励.
            uint rate = subtitles[index].top*100/(subtitles[index].top + subtitles[index].step);
            uint len = videos[_webindex].Applys[_language].VideoSubtitles.length;        
            uint sumtop = 0;
            for (uint i=0;i<len;i++) {
                sumtop +=  subtitles[videos[_webindex].Applys[_language].VideoSubtitles[i]].top;
            }
            if (((subtitles[index].top - subtitles[index].step > sumtop / len) || (len == 1 && rate > 60))&& sumtop > 1 && block.timestamp > videos[_webindex].Applys[_language].ApplyTime + 50 seconds ) {
                videos[_webindex].Applys[_language].IfSucess = true;
                videos[_webindex].Applys[_language].SucSubaddress = subtitles[index].ipfsaddress;
                videos[_webindex].Applys[_language].SuccessSubId = _subtitleindex;
                videos[_webindex].Applys[_language].SubOwner = subtitles[index].subtitleowner;
                subtitles[index].iftaking = true;
                User[subtitles[index].subtitleowner].creditpoints += 1;//只有字幕被采用时信誉度才会增加1，难度很大，减少作恶的可能性；
                subtitles[index].lastupdated = block.timestamp;//字幕被采纳时间，视频申请结束时间.
                emit confirm(_webindex,videos[_webindex].VideoName,_language,_subtitleindex);
            } 
        }
        onlyvoteone[msg.sender][_webindex][_language] = true;
        userforsubvote[msg.sender][index] = true;
        return true;
    }
    //当踩的数目达到一定比例，应将恶意字幕删除（置空）,同时给予上传者积分减去惩罚.
    function Step (uint _webindex,string memory _language,uint _subtitleindex) external onlyWhiteListUsr(msg.sender) returns(bool){
        uint index = videos[_webindex].Applys[_language].VideoSubtitles[_subtitleindex];
        if(User[msg.sender].ifcreate == false) {
            User[msg.sender].applypoints = 100;
            User[msg.sender].submitpoints = 100;
            User[msg.sender].creditpoints = 100;
            User[msg.sender].ifcreate = true;
        }
        require(User[msg.sender].creditpoints >= 60);
        require(userforsubvote[msg.sender][index] == false);
        require(videos[_webindex].Applys[_language].IfSucess == false);
        subtitles[index].step++;
        subtitles[index].stepaddress.push(msg.sender);
        userforsubvote[msg.sender][index] = true;
        if(subtitles[index].step >= 10*subtitles[index].top || (subtitles[index].top == 0 && subtitles[index].step > 10)){
            User[subtitles[index].subtitleowner].creditpoints -= 5;//惩罚积分减5.
            address[] memory stepaddress;
            uint len = subtitles[index].stepaddress.length;
            for (uint i=0;i<len;i++){
                stepaddress[i] = subtitles[index].stepaddress[i];
                User[stepaddress[i]].creditpoints += 1;
            }
            emit DeleteSub(_webindex, index, subtitles[index].ipfsaddress, subtitles[index].subtitlehash,stepaddress);
            delete subtitles[index];//并且删除该字幕，所有成员变量设为初值.
        }
        return true;
    }
}
