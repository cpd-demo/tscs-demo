// SPDX-License-Identifier: SimPL-2.0
pragma solidity >= 0.4.25 < 0.8.5;

import "./ERC777/ERC777.sol";
interface FlowOracleInterface {
    function getFlow(uint _webindex) external view returns(uint,uint,address);
    function getSubFlow(uint _webindex,string memory _language) external view returns(uint,uint);
}
interface SubtitleApplyInterface {
    function checkApply(uint _webindex) external view returns(bool);
    function getLanguage(uint _webindex)external view returns(uint,string[] memory);
    function checkApplyLa(uint _webindex,string memory _language)external view returns(bool);
    function returnRewardInfo(uint _webindex,string memory _language)external view returns(uint,uint,address,address[] memory);
    function returnSTPrice(uint _subtitleindex) external view returns(uint,address);
}
contract VideoToken is ERC777 {
    address CEO;
    address Wallet;
    address subtitleapplyaddr;
    uint videoproportion;
    uint fbproportion;
    uint interval;
    uint totalpaytoken;
    mapping(uint => VideoRecord) videosReward;
    mapping(uint => bool) sell;
    mapping(uint => address) sellST;
    event videoTokenReceived(address videowner,uint number);
    event subTokenReceived(address videowner,uint number,uint fbnumber);
    event buySTsucess(uint STindex,address STowner,address STnewowner);
    constructor(address[] memory defaultOperators,address payable wallet,uint initialSupply,uint _interval,uint _videoproportion,uint _fbproportion,address _oracleaddress,address _subtitleaddress) ERC777("VideoToken", "VT", defaultOperators,wallet,initialSupply)
    {   
          Wallet = wallet;
          CEO = msg.sender;
          videoproportion = _videoproportion;
          fbproportion = _fbproportion;
          interval = _interval;
          FlowOracle = FlowOracleInterface(_oracleaddress);
          SubtitleApply = SubtitleApplyInterface(_subtitleaddress);
          subtitleapplyaddr = _subtitleaddress;
    }

    FlowOracleInterface FlowOracle;
    SubtitleApplyInterface SubtitleApply;
    struct VideoRecord {
        uint lastflow;
        uint lastgettime;
        uint lastgettoken;
        uint totalgettoken;
        mapping(string => subRecord) subrecords;
    } 
    struct subRecord {
        bool pay1success;
        uint sublastflow;
        //type 1.
        bool create;
        uint surplus;
    }
   
   //ST购买相关.
   //返回ST是否售卖信息.
   function buyInfo(uint _STindex)external view returns(bool,address) {
       return (sell[_STindex],sellST[_STindex]);
   }
   //ST购买功能.
   function buyST(uint _STindex)public returns(bool){
        require(sell[_STindex] == false);
        uint price;
        address STowner;
        (price,STowner) = SubtitleApply.returnSTPrice(_STindex);
        if(price > 0) {
           bool result = transfer(STowner,price);
           if(result == true) {
               sellST[_STindex] = msg.sender;
               sell[_STindex] = true;
               emit buySTsucess(_STindex,STowner,msg.sender);
               return true;
           }
        }
        return false;
    }
    //重置ST售卖信息，防止重复售卖/给与购买者售卖权.
    function resetBuyInfo(uint _STindex)external {
        require(msg.sender == subtitleapplyaddr);
        sell[_STindex] = false;
        sellST[_STindex] = address(0);
    }
    //收益结算
    function getReward(uint _webindex) public {
    require(block.timestamp >= videosReward[_webindex].lastgettime + interval); 
        uint newvideoflow;
        address videowner;
        bool applyif;
        uint applynum;
        uint totalvideotoken;
        uint gettoken;
        (,newvideoflow,videowner) = FlowOracle.getFlow(_webindex); 
        (applyif) = SubtitleApply.checkApply(_webindex); 
        totalvideotoken = (newvideoflow - videosReward[_webindex].lastflow)*10**(18-videoproportion);
        burnreward(Wallet,totalvideotoken);
        if (applyif == false){
            gettoken = totalvideotoken;
            reward(videowner,gettoken);
            videosReward[_webindex].lastgettoken = gettoken;
            videosReward[_webindex].totalgettoken += gettoken;
            emit videoTokenReceived(videowner, gettoken);
        }else{     
           totalpaytoken = 0; 
           string[] memory applyla;
           (applynum,applyla) = SubtitleApply.getLanguage(_webindex);
            uint id;
           for (id = 0;id < applynum;id ++) {
                loopGet(_webindex, applyla[id],totalvideotoken);
           }
        }
        if (totalvideotoken > totalpaytoken) {
                gettoken = totalvideotoken - totalpaytoken;
                reward(videowner,gettoken);
                videosReward[_webindex].lastgettoken = gettoken;
                videosReward[_webindex].totalgettoken += gettoken;
                emit videoTokenReceived(videowner, gettoken);
        }
        videosReward[_webindex].lastflow = newvideoflow;
        videosReward[_webindex].lastgettime = block.timestamp;
    }
    function loopGet(uint _webindex,string memory _language,uint totalvideotoken) internal {
           uint paytype;
           uint paynumber;
           uint newsubflow;
           address subowner;
           address[] memory fbaddress;
           uint subtokens;
           uint fbtokens;
           uint totalsubtoken;
           uint totalfbtoken;
           bool ifsuccess;
           (ifsuccess) = SubtitleApply.checkApplyLa(_webindex,_language);
           if (ifsuccess == true) {
                  (paytype,paynumber,subowner,fbaddress) = SubtitleApply.returnRewardInfo(_webindex,_language);
                  (,newsubflow) = FlowOracle.getSubFlow(_webindex, _language);
                  totalsubtoken = (newsubflow - videosReward[_webindex].subrecords[_language].sublastflow)*10**(18-videoproportion);
                  videosReward[_webindex].subrecords[_language].sublastflow = newsubflow;
                  if (paytype == 0) {
                      subtokens = totalsubtoken/(10**paynumber);
                      totalfbtoken = subtokens/(10**fbproportion);
                      fbtokens = totalfbtoken/fbaddress.length;
                      totalpaytoken += subtokens;
                      reward(subowner,subtokens-totalfbtoken);
                      for(uint fbid=0;fbid<fbaddress.length;fbid++){
                         reward(fbaddress[fbid],fbtokens);
                      }
                  }else if(paytype == 1) {
                           if (videosReward[_webindex].subrecords[_language].create == false) {
                           videosReward[_webindex].subrecords[_language].surplus = paynumber*10**18;
                           videosReward[_webindex].subrecords[_language].create = true;
                           }
                           if (videosReward[_webindex].subrecords[_language].pay1success == false) {       
                               if(totalvideotoken >= videosReward[_webindex].subrecords[_language].surplus) {    
                                  subtokens = videosReward[_webindex].subrecords[_language].surplus;
                                  videosReward[_webindex].subrecords[_language].surplus = 0;
                                  videosReward[_webindex].subrecords[_language].pay1success = true;
                                }else {
                                  subtokens = totalvideotoken;
                                  videosReward[_webindex].subrecords[_language].surplus = videosReward[_webindex].subrecords[_language].surplus - subtokens;
                                }       
                                totalfbtoken = subtokens/(10**fbproportion);
                                fbtokens = totalfbtoken/fbaddress.length;
                                totalpaytoken += subtokens;
                                reward(subowner,subtokens-totalfbtoken);
                                for(uint fbid=0;fbid<fbaddress.length;fbid++){
                                    reward(fbaddress[fbid],fbtokens);
                                }              
                            }
                    }
                    emit subTokenReceived(subowner,subtokens-totalfbtoken,fbtokens);
                }
    }
 

}
