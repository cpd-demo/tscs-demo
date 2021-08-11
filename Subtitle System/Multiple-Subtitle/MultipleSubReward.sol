// SPDX-License-Identifier: SimPL-2.0
pragma solidity >= 0.4.25 < 0.8.5;

import "./ERC777/ERC777.sol";

interface FlowOracleInterface {
    function getFlow(uint video_index) external view returns(uint,uint,address);
    function getSubFlow(uint video_index,string memory _language) external view returns(uint,uint);
}
interface SubtitleApplyInterface {
    function checkApply(uint video_index) external view returns(bool);
    function getLanguage(uint video_index)external view returns(uint,string[] memory);
    function checkApplyLa(uint video_index,string memory _language)external view returns(bool);
    function returnRewardInfo(uint video_index,string memory _language)external view returns(uint,uint,address,address[] memory);
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
    uint totalvideotoken;
    mapping(uint => VideoRecord) videosReward;
    mapping(uint => bool) sell;
    mapping(uint => address) sellST;
    event videoTokenReceived(address video_wner,uint number);
    event subTokenReceived(address vide_owner,uint number,uint fb_number);
    event buySTsucess(uint ST_index,address ST_owner,address ST_newowner);
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
        mapping(string => subtitleRecord) Record;
    } 
    struct subtitleRecord {
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
   
    function buyST(uint _STindex)public {
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
           }
        }
    }
    //重置ST售卖信息，防止重复售卖/给与购买者售卖权.
    function resetBuyInfo(uint _STindex)external {
        require(msg.sender == subtitleapplyaddr);
        sell[_STindex] = false;
        sellST[_STindex] = address(0);
    }
    //收益结算
    function getReward(uint video_index) public {
    require(block.timestamp >= videosReward[video_index].lastgettime + interval); 
        uint newvideoflow;
        address videowner;
        bool applyif;
        uint applynum;
        uint gettoken;
        (,newvideoflow,videowner) = FlowOracle.getFlow(video_index); 
        (applyif) = SubtitleApply.checkApply(video_index); 
        totalvideotoken = (newvideoflow - videosReward[video_index].lastflow)*10**(18-videoproportion);
        burnreward(Wallet,totalvideotoken);
        if (applyif == false){
            gettoken = totalvideotoken;
            reward(videowner,gettoken);
            videosReward[video_index].lastgettoken = gettoken;
            videosReward[video_index].totalgettoken += gettoken;
            emit videoTokenReceived(videowner, gettoken);
        }else{     
           totalpaytoken = 0; 
           string[] memory applyla;
           (applynum,applyla) = SubtitleApply.getLanguage(video_index);
            uint id;
           for (id = 0;id < applynum;id ++) {
                loopGet(video_index, applyla[id]);
           }
        }
        if (totalvideotoken > 0) {
                gettoken = totalvideotoken - totalpaytoken;
                reward(videowner,gettoken);
                videosReward[video_index].lastgettoken = gettoken;
                videosReward[video_index].totalgettoken += gettoken;
                emit videoTokenReceived(videowner, gettoken);
        }
        videosReward[video_index].lastflow = newvideoflow;
        videosReward[video_index].lastgettime = block.timestamp;
    }
    function loopGet(uint video_index,string memory _language) internal {
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
           (ifsuccess) = SubtitleApply.checkApplyLa(video_index,_language);
           if (ifsuccess == true) {
                  (paytype,paynumber,subowner,fbaddress) = SubtitleApply.returnRewardInfo(video_index,_language);
                  if (paytype == 0) {
                      (,newsubflow) = FlowOracle.getSubFlow(video_index, _language);
                      totalsubtoken = (newsubflow - videosReward[video_index].Record[_language].sublastflow)*10**(18-videoproportion);
                      videosReward[video_index].Record[_language].sublastflow = newsubflow;
                      subtokens = totalsubtoken/(10**paynumber);
                      videosReward[video_index].Record[_language].surplus += subtokens;
                      if(totalvideotoken >= videosReward[video_index].Record[_language].surplus) {    
                            subtokens = videosReward[video_index].Record[_language].surplus;
                            videosReward[video_index].Record[_language].surplus = 0;
                            totalvideotoken -= subtokens;
                        }else {
                            subtokens = totalvideotoken;
                            videosReward[video_index].Record[_language].surplus -= subtokens;
                            totalvideotoken = 0;
                        }    
                      totalfbtoken = subtokens/(10**fbproportion);
                      fbtokens = totalfbtoken/fbaddress.length;
                      reward(subowner,subtokens-totalfbtoken);
                      for(uint fbid=0;fbid<fbaddress.length;fbid++){
                         reward(fbaddress[fbid],fbtokens);
                      }
                  }else if(paytype == 1) {
                           if (videosReward[video_index].Record[_language].create == false) {
                           videosReward[video_index].Record[_language].surplus = paynumber*10**18;
                           videosReward[video_index].Record[_language].create = true;
                           }
                           if (videosReward[video_index].Record[_language].pay1success == false) {       
                               if(totalvideotoken >= videosReward[video_index].Record[_language].surplus) {    
                                  subtokens = videosReward[video_index].Record[_language].surplus;
                                  videosReward[video_index].Record[_language].surplus = 0;
                                  videosReward[video_index].Record[_language].pay1success = true;
                                  totalvideotoken -= subtokens;
                                }else {
                                  subtokens = totalvideotoken;
                                  videosReward[video_index].Record[_language].surplus = videosReward[video_index].Record[_language].surplus - subtokens;
                                  totalvideotoken = 0;
                                }       
                                totalfbtoken = subtokens/(10**fbproportion);
                                fbtokens = totalfbtoken/fbaddress.length;
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
