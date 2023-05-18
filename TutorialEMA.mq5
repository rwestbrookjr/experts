#include <Trade/Trade.mqh>


// inputs
input int      StopLoss = 1000;
input int      TakeProfit = 10000;
input int      EMAFast_Period = 5;
input int      EMAMed_Period = 20;
input int      EMASlow_Period = 50;
input int      EA_Magic = 122305;
input double   Lot = 5.0;

// globals
double   fema[];
double   mema[];
double   sema[];
double   atr[];
double   p_close;
int      femaHandle;
int      memaHandle;
int      semaHandle;
int      atrHandle;
int      STP, TKP, DIG;
ulong    TicketNumber = 0;
CTrade   trade;
double   currentSl,currentTp;

int OnInit(){
   femaHandle = iMA(_Symbol,PERIOD_CURRENT,EMAFast_Period,0,MODE_EMA,PRICE_CLOSE);
   memaHandle = iMA(_Symbol,PERIOD_CURRENT,EMAMed_Period,0,MODE_EMA,PRICE_CLOSE);
   semaHandle = iMA(_Symbol,PERIOD_CURRENT,EMASlow_Period,0,MODE_EMA,PRICE_CLOSE);
   atrHandle = iATR(_Symbol,PERIOD_CURRENT,5);
   
   if(femaHandle<0 || memaHandle<0 || semaHandle<0 || atrHandle<0){
      Alert("Error creating handles for indicators - error: ", GetLastError(), "!!");
   }
   
   // Let us handle currency pairs with 5 or 3 digit prices instead of 4
   STP = StopLoss;
   TKP = TakeProfit;
   if(_Digits==5 || _Digits==3){
      STP = STP*10;
      TKP = TKP*10;
      DIG = _Digits;
   }else{
      DIG = 2;
   }
   
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){
   IndicatorRelease(femaHandle);
   IndicatorRelease(memaHandle);
   IndicatorRelease(semaHandle);
   IndicatorRelease(atrHandle);
   
}
void OnTick(){
   // Do we have enough bars to work with
   if(Bars(_Symbol,PERIOD_CURRENT)<55){ //If total bars is less than 55 bars
      Alert("We have less than 55 bars, EA will now exit!!");
      return;
   }
   
   // We will use the static Old_Time variable to serve the bar time.
   // At each OnTick execution we will check the current bar time with the saved one.
   // If the bar time isn't equal to the saved time, it indicates that we have a new tick.
   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar=false;

   // copying the last bar time to the element New_Time[0]
   int copied=CopyTime(_Symbol,_Period,0,1,New_Time);
   if(copied>0){ // ok, the data has been copied successfully
      if(Old_Time!=New_Time[0]){ // if old time isn't equal to new bar time  
         IsNewBar=true;   // if it isn't a first call, the new bar has appeared
         if(MQL5InfoInteger(MQL5_DEBUGGING)) Print("We have new bar here ",New_Time[0]," old time was ",Old_Time);
         Old_Time=New_Time[0];            // saving bar time
      }
   }
   else{
      Alert("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
      return;
   }
   
   //--- EA should only check for new trade if we have a new bar
   if(IsNewBar==false){
      return;
   }

   //--- Define some MQL5 Structures we will use for our trade
   MqlTick latest_price;     // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates mrate[];         // To be used to store the prices, volumes and spread of each bar
   ZeroMemory(mrequest);     // Initialization of mrequest structure
   
   /*
     Let's make sure our arrays values for the Rates, ADX Values and MA values 
     is store serially similar to the timeseries array
   */
   // the fema arrays
      ArraySetAsSeries(fema,true);
   // the mema array
      ArraySetAsSeries(mema,true);
   // the sema array
      ArraySetAsSeries(sema,true);
   // the mrate arrays
      ArraySetAsSeries(mrate,true);
   // the atr arrays
      ArraySetAsSeries(atr,true);
      
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
   
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(femaHandle,0,0,3,fema)<0 || CopyBuffer(memaHandle,0,0,3,mema)<0 || CopyBuffer(semaHandle,0,0,3,sema)<0 || CopyBuffer(atrHandle,0,0,3,atr)<0){
      Alert("Error copying Moving Average Indicator Buffers - error:",GetLastError(),"!!");
      return;
   }
   
   //--- we have no errors, so continue
   //--- Do we have positions opened already?
    bool Buy_opened = false;  // variable to hold the result of Buy opened position
    bool Sell_opened = false; // variable to hold the result of Sell opened position
    
    if (PositionSelect(_Symbol) ==true)  // we have an opened position
    {
         if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            Buy_opened = true;  //It is a Buy
            UpdateLongTsl(TicketNumber);
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            Sell_opened = true; // It is a Sell
            UpdateShortTsl(TicketNumber);
         }
    }else{
      TicketNumber = 0;
    }
    
    
    
    // Copy the bar close price for the previous bar prior to the current bar, that is Bar 1
    //p_close = mrate[1].close; //bar 1 close price
    
    /*
    1. Check for a long/Buy Setup : MA-8 increasing upwards, 
    previous price close above it, ADX > 22, +DI > -DI
   */
   //--- Declare bool type variables to hold our Buy Conditions
   bool Buy_Condition_1 = (mrate[0].close > (mema[0]-atr[0]));                 // 5EMA cross above 20EMA
   //bool Buy_Condition_2 = (mrate[0].close > sema[0] && mrate[0].close > mema[0] && fema[0] > mema[0]);   // 5EMA above 20EMA and price close above 5EMA
   /*bool Buy_Condition_3 = (adxVal[0]>Adx_Min);          // Current ADX value greater than minimum value (22)
   bool Buy_Condition_4 = (plsDI[0]>minDI[0]);          // +DI greater than -DI
   */

   //--- Putting all together   
   if(Buy_Condition_1){
      // any opened Buy position?
      if (Buy_opened || Sell_opened){
         Alert("We already have an open position!!!"); 
         return;    // Don't open a new Position
      }
      mrequest.action = TRADE_ACTION_DEAL;                                    // immediate order execution
      mrequest.price = NormalizeDouble(latest_price.ask,DIG);                 // latest ask price
      //mrequest.sl = NormalizeDouble(mrequest.price - STP,DIG);              // Stop Loss
      mrequest.sl = NormalizeDouble(mema[0]-atr[0],DIG);                             // Stop Loss
      //mrequest.tp = NormalizeDouble(mrequest.price + TKP,DIG);                // Take Profit
      mrequest.symbol = _Symbol;                                              // currency pair
      mrequest.volume = Lot;                                                  // number of lots to trade
      mrequest.magic = EA_Magic;                                              // Order Magic Number
      mrequest.type = ORDER_TYPE_BUY;                                         // Buy Order
      mrequest.type_filling = ORDER_FILLING_FOK;                              // Order execution type
      mrequest.deviation=100;                                                 // Deviation from current price
      //--- send order
      if(!OrderSend(mrequest,mresult)){
         Alert("Failed to send buy order with Error: ", mresult.comment," !!");
      }
      
      // get the result code
      if(mresult.retcode==10009 || mresult.retcode==10008){ //Request is completed or order placed
         Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
         TicketNumber = mresult.order;
      } else {
         Alert("The Buy order request could not be completed -error:",GetLastError());
         ResetLastError();           
         return;
      }
    }
    
    /*
    2. Check for a Short/Sell Setup : MA-8 decreasing downwards, 
    previous price close below it, ADX > 22, -DI > +DI
   */
   //--- Declare bool type variables to hold our Sell Conditions
   bool Sell_Condition_1 = (mrate[0].close < (mema[0]+atr[0]));                   // 5EMA cross below 20EMA
   //bool Sell_Condition_2 = (mrate[0].close < sema[0] && mrate[0].close < mema[0] && fema[0] < mema[0]);     // 5EMA below 20EMA and price close below 5EMA
   /*bool Sell_Condition_3 = (adxVal[0]>Adx_Min);                                                           // Current ADX value greater than minimum (22)
   bool Sell_Condition_4 = (plsDI[0]<minDI[0]);                                                             // -DI greater than +DI
   */
   
   //--- Putting all together
   if(Sell_Condition_1){
      // any opened Sell position?
      if (Sell_opened || Buy_opened){
          Alert("We already have an position!!!"); 
          return;    // Don't open a new Position
      }
      mrequest.action = TRADE_ACTION_DEAL;                                       // immediate order execution
      mrequest.price = NormalizeDouble(latest_price.bid,DIG);                    // latest Bid price
      //mrequest.sl = NormalizeDouble(mrequest.price + STP,DIG);                 // Stop Loss
      mrequest.sl = NormalizeDouble(mema[0]+atr[0],DIG);                         // Stop Loss
      //mrequest.tp = NormalizeDouble(mrequest.price - TKP,DIG);                 // Take Profit
      mrequest.symbol = _Symbol;                                                 // currency pair
      mrequest.volume = Lot;                                                     // number of lots to trade
      mrequest.magic = EA_Magic;                                                 // Order Magic Number
      mrequest.type= ORDER_TYPE_SELL;                                            // Sell Order
      mrequest.type_filling = ORDER_FILLING_FOK;                                 // Order execution type
      mrequest.deviation=100;                                                    // Deviation from current price
      //--- send order
      if(!OrderSend(mrequest,mresult)){
         Alert("Failed to send sell order with Error: ", mresult.comment," !!");
      }

      if(mresult.retcode==10009 || mresult.retcode==10008){ //Request is completed or order placed
         Alert("A Sell order has been successfully placed with Ticket#:",mresult.order,"!!");
         TicketNumber = mresult.order;
      }else{
         Alert("The Sell order request could not be completed -error:",GetLastError());
         ResetLastError();
         return;
      }
   }
   
}

void UpdateLongTsl(ulong Ticket){
   if(PositionSelectByTicket(Ticket)){
      PositionGetDouble(POSITION_SL,currentSl);
      PositionGetDouble(POSITION_TP, currentTp);
   }
   
   if(mema[0]-atr[0] > currentSl){
      currentSl = mema[0]-atr[0];
   }
   
   trade.PositionModify(Ticket,currentSl, currentTp);
   
}

void UpdateShortTsl(ulong Ticket){
   if(PositionSelectByTicket(Ticket)){
      PositionGetDouble(POSITION_SL,currentSl);
      PositionGetDouble(POSITION_TP, currentTp);
   }
   
   if(mema[0]+atr[0] < currentSl){
      currentSl = mema[0]+atr[0];
   }
   
   trade.PositionModify(Ticket,currentSl, currentTp);
   
}