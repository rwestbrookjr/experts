#include <Trade/Trade.mqh>

CTrade Trade;
input double   lot = 0.1;
input int      stop = 10;
input int      target = 50;

double lastClose, lastOpen, lastLow, lastHigh;
ulong  TicketNumber;
int OnInit(){
   

   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){
   
}
void OnTick(){

   MqlRates mrate[];         // To be used to store the prices, volumes and spread of each bar
   MqlTick latest_price;     // To be used for getting recent/latest price quotes
   
   lastOpen    = iOpen(_Symbol,PERIOD_H4,1);
   lastHigh    = iHigh(_Symbol,PERIOD_H4,1);
   lastLow     = iLow(_Symbol,PERIOD_H4,1);
   lastClose   = iClose(_Symbol,PERIOD_H4,1);
   
   // the mrate arrays
   ArraySetAsSeries(mrate,true);
   
   //--- Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol,latest_price)){
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
   }
   
   //--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0){
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      return;
   }
   
   //--- we have no errors, so continue
   //--- Do we have positions opened already?
   bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variable to hold the result of Sell opened position
    
   if (PositionSelect(_Symbol) ==true){  // we have an opened position
      double currentSl,currentTp;
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
         Buy_opened = true;  //It is a Buy
         if(PositionSelectByTicket(TicketNumber)){
            PositionGetDouble(POSITION_SL,currentSl);
            PositionGetDouble(POSITION_TP, currentTp);
         }
         
         if((mrate[0].close-stop) > currentSl){
            currentSl = mrate[0].close-stop;
            Trade.PositionModify(TicketNumber,currentSl, currentTp);
         }         
      }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
         Sell_opened = true; // It is a Sellif(PositionSelectByTicket(TicketNumber)){
         PositionGetDouble(POSITION_SL, currentSl);
         PositionGetDouble(POSITION_TP, currentTp);
      }
      
      if((mrate[0].close+stop) < currentSl){
         currentSl = (mrate[0].close+stop);
         Trade.PositionModify(TicketNumber,currentSl, currentTp);
      }
      
      
   }else{
      TicketNumber = 0;
   }
   bool prevCandleDown = lastClose < lastOpen;
   bool prevCandleUp = lastClose > lastOpen;
   if(!PositionSelect(_Symbol)){
      if(mrate[0].close > lastClose){
         Trade.Sell(lot,_Symbol,lastClose,lastClose + stop, lastClose - target, "Sell!!");
      }else if(mrate[0].close < lastClose){
         Trade.Buy(lot,_Symbol,lastClose,lastClose - stop, lastClose + target, "Buy!!");
      }
   }
}
   
//Update trailing stops as needed
//void UpdateLongTsl(ulong TicketNumber){
//   if(PositionSelectByTicket(TicketNumber)){
//      PositionGetDouble(POSITION_SL,currentSl);
//      PositionGetDouble(POSITION_TP, currentTp);
//   }
//   
//   if(sema[0] > currentSl){
//      currentSl = sema[0];
//   }
//   
//   Trade.PositionModify(TicketNumber,currentSl, currentTp);
//   
//}
//
//void UpdateShortTsl(ulong TicketNumber){
//   if(PositionSelectByTicket(TicketNumber)){
//      PositionGetDouble(POSITION_SL, currentSl);
//      PositionGetDouble(POSITION_TP, currentTp);
//   }
//   
//   if(sema[0] < currentSl){
//      currentSl = sema[0];
//   }
//   
//   Trade.PositionModify(TicketNumber,currentSl, currentTp);
//   
//}

