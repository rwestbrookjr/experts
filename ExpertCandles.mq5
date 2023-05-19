#include <Trade/Trade.mqh>


// Standard inputs
input int       EA_Magic = 122305;
input int       LookBack = 0;
input int       mytp = 200;
input double    Lot = 1.0;

// Standard globals
CTrade  trade;
ulong   TicketNumber = 0;
double  currentSl,currentTp,slLong,slShort;
MqlRates mrate[];
MqlTick latest_price; 

// Init function
int OnInit(){

   return(INIT_SUCCEEDED);
}

// Deinit function
void OnDeinit(const int reason){
   // Release indicator handles here
   
}

// On Tick function
void OnTick(){
    // Do we have enough bars to work with
    if(Bars(_Symbol,PERIOD_CURRENT)<(LookBack + 10)){ //If total bars is less than LookBack + 10 bars
        Alert("We have less than ",LookBack+10," bars, EA will now exit!!");
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

    /*
        Let's make sure our arrays values for the Rates, ADX Values and MA values 
        is store serially similar to the timeseries array
    */
    // the mrate arrays
        ArraySetAsSeries(mrate,true);
        
    //--- Get the last price quote using the MQL5 MqlTick Structure
    if(!SymbolInfoTick(_Symbol,latest_price)){
        Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
        return;
    }

    //--- Get the details of the latest 10 bars plus any required lookback
    if(CopyRates(_Symbol,_Period,0,LookBack+10,mrate)<0){
        Alert("Error copying rates/history data - error:",GetLastError(),"!!");
        return;
    }
    

    bool buy = false;
    bool sell = false;

    // Check for existing order
    if(PositionSelect(_Symbol)==true){
        TicketNumber = PositionGetTicket(0);
        // Open position, do not open another just adjust stop
        UpdateStop(TicketNumber,PositionGetInteger(POSITION_TYPE),slLong,slShort);
        return;
    }else{
        if(buy){
            trade.Buy(Lot,_Symbol,NULL,slLong,latest_price.ask + mytp,"BUY!");
        }
        if(sell){
            trade.Sell(Lot,_Symbol,NULL,slLong,latest_price.bid - mytp,"SELL!");
        }
    }
}

// Utility functions

// Trail Stop Calculator
void UpdateStop(ulong Ticket, long side,double longSL, double shortSL){
    if(PositionSelectByTicket(Ticket)){
        PositionGetDouble(POSITION_SL,currentSl);
        PositionGetDouble(POSITION_TP, currentTp);
        
    } else {
        Alert("Unable to retrieve postition by ticket#.");
        return;
    }
    
    //currentSl = round(currentSl);
    //longSL = round(longSL);
    //shortSL = round(shortSL);
    // Check Stop
    if(currentSl == longSL || currentSl == shortSL){//Do nothing just return
        return;
    }
    if(side==0){//long
        if(currentSl < longSL){
            currentSl = longSL;
            if(!trade.PositionModify(Ticket,currentSl, currentTp)){
                Alert("Unable to modify posiiton!");
                return;
            }
        }
    }else if(side==1){//short
        if(currentSl > shortSL){
            currentSl = shortSL;
            if(!trade.PositionModify(Ticket,currentSl, currentTp)){
                Alert("Unable to modify posiiton!");
                return;
            }
        }
    }else{
        Alert("Invalid Side Identifier!");
        return;
    }
}

