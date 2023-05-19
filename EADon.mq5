#include <Trade/Trade.mqh>


// Standard inputs
input int       EA_Magic = 122305;
input int       LookBack = 20;
input int       SpanMin = 200;
input int       mytp = 200;
input double    Lot = 1.0;

// Standard globals
CTrade  trade;
ulong   TicketNumber = 0;
double  currentSl,currentTp,donHigh,donLow,donMid,donHS,donHL,donSpan;
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

    //--- Get the details of the latest 3 bars
    if(CopyRates(_Symbol,_Period,0,LookBack+10,mrate)<0){
        Alert("Error copying rates/history data - error:",GetLastError(),"!!");
        return;
    }
    
    CalculateDonchianValues();
    
    donMid = NormalizeDouble(((donHigh + donLow)/2),_Digits);
    donSpan = donHigh - donLow;

    bool buy = mrate[0].close > donMid && donSpan > SpanMin;
    bool sell = mrate[0].close < donMid && donSpan > SpanMin;

    // Check for existing order
    if(PositionSelect(_Symbol)==true){
        TicketNumber = PositionGetTicket(0);
        // Open position, do not open another just adjust stop
        CalcTsp(TicketNumber,PositionGetInteger(POSITION_TYPE),donHL,donHS);
        return;
    }else{
        if(buy){
            trade.Buy(Lot,_Symbol,NULL,donHL,latest_price.ask + mytp,"BUY!");
        }
        if(sell){
            trade.Sell(Lot,_Symbol,NULL,donHS,latest_price.bid - mytp,"SELL!");
        }
    }
}

// Utility functions

// Calculate Donchian Values
void CalculateDonchianValues(){
    // Calc High of last LookBack bars
    for (int i = 1; i <= LookBack; i++)
    {
        double high = mrate[i].high;

        // Check if the current high is higher than the previous highest high
        if (high > donHigh)
            donHigh = high;
    }
    donHS = 0.0;
    // Calc Half High for short stops
    for (int i = 1; i <= LookBack/2; i++)
    {
        double high = mrate[i].high;

        // Check if the current high is higher than the previous highest high
        if (high > donHS)
            donHS = high;
    }
    
    
    // Calc Low of last LookBack bars
    for (int i = 1; i <= LookBack; i++)
    {
        double low = mrate[i].low;

        // Check if the current high is higher than the previous highest high
        if (low < donLow || donLow == 0.0)
            donLow = low;
    }
    donHL = 0.0;
    // Calc Half Low for long stops
    for (int i = 1; i <= LookBack/2; i++)
    {
        double low = mrate[i].low;

        // Check if the current high is higher than the previous highest high
        if (low < donHL || donHL == 0.0)
            donHL = low;
    }
}

// Trail Stop Calculator
void CalcTsp(ulong Ticket, long side,double longSL, double shortSL){
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
    
    // if(!trade.PositionModify(Ticket,currentSl, currentTp)){
    //     Alert("Unable to modify posiiton!");
    //     return;
    // }
}

