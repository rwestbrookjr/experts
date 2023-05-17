//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>

// Input parameters
input int EMA5_Period = 5;
input int EMA20_Period = 20;
input int EMA50_Period = 50;
input double Lots = 0.1;

// Global variables
double EMA50;
double EMA5;
double EMA20;

ulong posTicket;
double curPrice;

int handleFEMA;
int handleMEMA;
int handleSEMA;


CTrade trade;

int barsTotal;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {

// Calculate the initial values of EMA
   EMA50 = iMA(_Symbol,PERIOD_CURRENT,EMA50_Period,0,MODE_EMA,PRICE_CLOSE);
   EMA5 = iMA(_Symbol,PERIOD_CURRENT,EMA5_Period,0,MODE_EMA,PRICE_CLOSE);
   EMA20 = iMA(_Symbol,PERIOD_CURRENT,EMA20_Period,0,MODE_EMA,PRICE_CLOSE);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
  curPrice = SymbolInfoDouble(_Symbol,SYMBOL_LAST);
// Check if the current price is above EMA50 and EMA5 is above EMA20
   if(curPrice > EMA50 && EMA5 > EMA20){
      // Open a long position
      if(posTicket <= 0)
        {
         trade.Buy(Lots,_Symbol);
         posTicket = trade.ResultOrder();
        }
     }

   if(curPrice < EMA50 && EMA5 < EMA20){
   // Open a short postition
      if(posTicket <= 0){
         trade.Sell(Lots, _Symbol);
         posTicket = trade.ResultOrder();
      }
   }
   
   if(PositionSelectByTicket(posTicket)){
      double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSl = PositionGetDouble(POSITION_SL);
      double posTp = PositionGetDouble(POSITION_TP);
      long posType = PositionGetInteger(POSITION_TYPE);
      Comment("Position Type: ", posType,
               "\nEMA5: ", EMA5,
               "\nEMA20: ", EMA20,
               "\nEMA50: ",EMA50,
               "\nClose: ",curPrice);
   }

// Update the values of EMA
   EMA50 = iMA(_Symbol,PERIOD_CURRENT,EMA50_Period,0,MODE_EMA,PRICE_CLOSE);
   EMA5 = iMA(_Symbol,PERIOD_CURRENT,EMA5_Period,0,MODE_EMA,PRICE_CLOSE);
   EMA20 = iMA(_Symbol,PERIOD_CURRENT,EMA20_Period,0,MODE_EMA,PRICE_CLOSE);
  }
//+------------------------------------------------------------------+
