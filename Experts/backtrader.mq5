﻿//+------------------------------------------------------------------+
//
// Copyright (C) 2019 Nikolai Khramkov
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//+------------------------------------------------------------------+

// TODO: Close position
// TODO: Close orders
// TODO: Check If SymbolExist
// TODO: Check TF according to request -> change
// TODO: Check chart symbol according to request -> change
// TODO: RETURN OK or error
// TODO: Write comment about sockets
// TODO: Add defauld dict check
// TODO: Change description
// TODO: Comissinos

#property copyright "Copyright 2019, Nikolai Khramkov."
#property link      "https://github.com/khramkov"
#property version   "0.70"

#include <Zmq/Zmq.mqh>
#include <json.mqh>

extern string PROJECT_NAME="Backtrader <-> Metatrader 5 interface";
extern string PROTOCOL="tcp";
extern string HOST="*";
extern int SYS_PORT=15555;
extern int DATA_PORT=15556;
extern int LIVE_PORT=15557;
extern int MILLISECOND_TIMER=1;  // 1 millisecond

// ZeroMQ Cnnections
Context context(PROJECT_NAME);
Socket sysSocket(context,ZMQ_REP);
Socket dataSocket(context,ZMQ_PUSH);
Socket liveSocket(context,ZMQ_PUSH);

// Global variables
bool debug = true;
datetime lastBar = 0;
string symbol = _Symbol;
ENUM_TIMEFRAMES period = _Period;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   /*
       Bindinig ZMQ ports on init
   */

   // Set Millisecond Timer to get client socket input
   EventSetMillisecondTimer(MILLISECOND_TIMER);

   Print("[REP] Binding System Socket on port "+IntegerToString(SYS_PORT)+"...");
   sysSocket.bind(StringFormat("%s://%s:%d",PROTOCOL,HOST,SYS_PORT));
   
   Print("[PUSH] Binding Data Socket on port "+IntegerToString(DATA_PORT)+"...");
   dataSocket.bind(StringFormat("%s://%s:%d",PROTOCOL,HOST,DATA_PORT));
   
   Print("[PUSH] Binding Live Socket on port "+IntegerToString(LIVE_PORT)+"...");
   liveSocket.bind(StringFormat("%s://%s:%d",PROTOCOL,HOST,LIVE_PORT));

   // Maximum amount of time in milliseconds that the thread will try to send messages 
   // after its socket has been closed (the default value of -1 means to linger forever):
   sysSocket.setLinger(1000);

   // How many messages do we want ZeroMQ to buffer in RAM before blocking the socket?
   // 3 messages only.
   sysSocket.setSendHighWaterMark(3);
   dataSocket.setSendHighWaterMark(3);
   liveSocket.setSendHighWaterMark(3);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   /*
       Closing ports on denit
   */
   Print("[REP] Unbinding socket on port "+IntegerToString(SYS_PORT)+"..");
   sysSocket.unbind(StringFormat("%s://%s:%d",PROTOCOL,HOST,SYS_PORT));

   Print("[PUSH] Unbinding socket on port "+IntegerToString(DATA_PORT)+"..");
   dataSocket.unbind(StringFormat("%s://%s:%d",PROTOCOL,HOST,DATA_PORT));

   Print("[PUSH] Unbinding socket on port "+IntegerToString(LIVE_PORT)+"..");
   liveSocket.unbind(StringFormat("%s://%s:%d",PROTOCOL,HOST,LIVE_PORT));

  }
//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {
   ZmqMsg request;
   
   // Get client's response, but don't wait.
   sysSocket.recv(request,true);

   // Generating reply by passing request to ZmqMsg MessageHandler() function.
   ZmqMsg reply=MessageHandler(request);

   // Reply  to client via REP socket.
   sysSocket.send(reply);
  }
  
//+------------------------------------------------------------------+
//| Request handler                                                  |
//+------------------------------------------------------------------+
ZmqMsg MessageHandler(ZmqMsg &request)
  {
   ZmqMsg reply;
   CJAVal message;

   if(request.size()>0)
     {
      
      string msg=request.getData();
      
      if(debug==true) {Print("Processing request:"+msg);}
         
      if(!message.Deserialize(msg))
        {
         Alert("Deserialization Error");
         
         //ExpertRemove();
         //return;
        }
      
      string action = message["action"].ToStr();
      
      if(action=="CHECK") {CheckConnection(&dataSocket, &liveSocket);}
      else if(action=="CONFIG") {ConfigScript(&dataSocket, message);}
      else if(action=="ACCOUNT") {AccountInfo(&dataSocket);}
      else if(action=="BALANCE") {BalanceInfo(&dataSocket);}
      else if(action=="HISTORY") {HistoryInfo(&dataSocket, message);}
      else if(action=="POSITIONS_INFO") {GetPositionsInfo(&dataSocket);}
      else if(action=="ORDERS_INFO") {GetOrdersInfo(&dataSocket);}
      else if(action=="TRADE") {TradingModule(&dataSocket, message);}
      else {} // error processing
      
      // Construct response
      ZmqMsg ret("OK");
      reply=ret;

     }
   else
     {
      // NO DATA RECEIVED
      ZmqMsg ret("FALSE");
      reply=ret;
     }

   return(reply);
  }

//+------------------------------------------------------------------+
//| Check sockets connection                                         |
//+------------------------------------------------------------------+
void CheckConnection (Socket &dataSocket, Socket &liveSocket)
   {
      InformClientSocket(dataSocket,"OK");
      InformClientSocket(liveSocket,"OK");
   }


//+------------------------------------------------------------------+
//| Reconfigure the script params                                    |
//+------------------------------------------------------------------+
void ConfigScript(Socket &dataSocket, CJAVal &dataObject)
  {  

  }

//+------------------------------------------------------------------+
//| Change chart timeframe                                           |
//+------------------------------------------------------------------+
void CheckTimeframe(Socket &dataSocket, CJAVal &dataObject)
  {
      string chartTF=dataObject["chartTF"].ToStr();
      
      if(chartTF=="1m") {period=PERIOD_M1;}
      else if(chartTF=="5m") {period=PERIOD_M5;}
      else if(chartTF=="15m") {period=PERIOD_M15;}
      else if(chartTF=="30m") {period=PERIOD_M30;}
      else if(chartTF=="1h") {period=PERIOD_H1;}
      else if(chartTF=="2h") {period=PERIOD_H2;}
      else if(chartTF=="3h") {period=PERIOD_H3;}
      else if(chartTF=="4h") {period=PERIOD_H4;}
      else if(chartTF=="6h") {period=PERIOD_H6;}
      else if(chartTF=="8h") {period=PERIOD_H8;}
      else if(chartTF=="12h") {period=PERIOD_H12;}
      else if(chartTF=="1d") {period=PERIOD_D1;}
      else if(chartTF=="1w") {period=PERIOD_W1;}
      else if(chartTF=="1M") {period=PERIOD_MN1;}
  }
  
//+------------------------------------------------------------------+
//| Account information                                              |
//+------------------------------------------------------------------+
void AccountInfo(Socket &dataSocket)
  {  
      CJAVal info;
      
      info["brocker"] = AccountInfoString(ACCOUNT_COMPANY);
      info["currency"] = AccountInfoString(ACCOUNT_CURRENCY);
      info["server"] = AccountInfoString(ACCOUNT_SERVER);    
      info["balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
      info["equity"] = AccountInfoDouble(ACCOUNT_EQUITY);
      info["margin"] = AccountInfoDouble(ACCOUNT_MARGIN);
      info["margin_free"] = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      info["margin_level"] = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      info["bot_trading"] = AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
      string t=info.Serialize();
      if(debug==true) {Print(t);}
      InformClientSocket(dataSocket,t);
  }

//+------------------------------------------------------------------+
//| Balance information                                              |
//+------------------------------------------------------------------+
void BalanceInfo(Socket &dataSocket)
  {  
      CJAVal info;
         
      info["balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
      info["equity"] = AccountInfoDouble(ACCOUNT_EQUITY);
      info["margin"] = AccountInfoDouble(ACCOUNT_MARGIN);
      info["margin_free"] = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      string t=info.Serialize();
      if(debug==true) {Print(t);}
      InformClientSocket(dataSocket,t);
  }
  

//+------------------------------------------------------------------+
//| Get historical data                                              |
//+------------------------------------------------------------------+
void HistoryInfo(Socket &dataSocket, CJAVal &dataObject)
  {   
      CJAVal candles;
      MqlRates rates[];
      
      int copied;    
      string actionType=dataObject["actionType"].ToStr();
      string symbol=dataObject["symbol"].ToStr();
      string chartTF=dataObject["chartTF"].ToStr();
      datetime startTime=dataObject["startTime"].ToInt();

      if(debug==true)
         {
         Print("Fetching HISTORY");
         Print("1) Symbol:"+symbol);
         Print("2) Timeframe:"+chartTF);
         Print("3) Date from:"+TimeToString(startTime));
         }
      copied=CopyRates(symbol,period,startTime,TimeCurrent(),rates);
      if(copied)

        {
         for(int i=0;i<copied;i++)
           {
            candles[i].Add(rates[i].time,TIME_DATE|TIME_MINUTES|TIME_SECONDS);
            candles[i].Add(rates[i].open);
            candles[i].Add(rates[i].high);
            candles[i].Add(rates[i].low);
            candles[i].Add(rates[i].close);
            candles[i].Add(rates[i].tick_volume);
           }
         string t=candles.Serialize();
         if(debug==true) {Print(t);}
         InformClientSocket(dataSocket,t);
        }
  }

//+------------------------------------------------------------------+
//| Fetch positions information                               |
//+------------------------------------------------------------------+
void GetPositionsInfo(Socket &dataSocket)
  {
   
   if(debug==true) {Print("Fetching positions...");}
   
   CJAVal data, position;

   // get positions  
   int positionsTotal=PositionsTotal();
   if(positionsTotal!=0)
     {
      // go through positions in a loop
      for(int i=0;i<positionsTotal;i++)
        {
         ResetLastError();
         // copy into the cache, the position by its number in the list
         // the position was copied into the cache, work with it
         if(PositionGetSymbol(i)!="")
            {
               position["id"] = PositionGetInteger(POSITION_IDENTIFIER);
               position["magic"] = PositionGetInteger(POSITION_MAGIC);
               position["symbol"] = PositionGetString(POSITION_SYMBOL);
               position["type"] = EnumToString(ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE)));
               position["time_setup"]=PositionGetInteger(POSITION_TIME);
               position["open"] = PositionGetDouble(POSITION_PRICE_OPEN);
               position["stoploss"] = PositionGetDouble(POSITION_SL);
               position["takeprofit"] = PositionGetDouble(POSITION_TP);
               position["volume"] = PositionGetDouble(POSITION_VOLUME);
               
               data["positions"].Add(position);
            }
         else        
           {
            // call PositionGetSymbol() was completed unsuccessfully
            data["error"]= GetLastError();
            PrintFormat("Error when obtaining an positions from the list to the cache. Error code: %d",GetLastError());
           }
         }
       }
       
    else
       {
         // if no open positions
         data["positions"].Add(0);
       }
    
    string t=data.Serialize();
    if(debug==true) {Print(t);}
    InformClientSocket(dataSocket,t);
     
  }

//+------------------------------------------------------------------+
//| Fetch orders information                               |
//+------------------------------------------------------------------+
void GetOrdersInfo(Socket &dataSocket)
  {
   
   if(debug==true) {Print("Fetching orders...");}
   
   CJAVal data, order;

   // get orders  
   int ordersTotal=OrdersTotal();
   if(ordersTotal!=0)
     {
      // go through orders in a loop 
      for(int i=0;i<ordersTotal;i++)
       {
         ResetLastError();
         // copy into the cache, the order by its number in the list
         ulong ticket=OrderGetTicket(i);
         Print(ticket);
         // if the order was successfully copied into the cache, work with it
         if(ticket!=0)
           {
            order["id"] = IntegerToString(ticket);
            order["magic"] = OrderGetInteger(ORDER_MAGIC); 
            order["symbol"] = OrderGetString(ORDER_SYMBOL);
            order["type"] = EnumToString(ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)));
            order["time_setup"]=OrderGetInteger(ORDER_TIME_SETUP);
            order["open"] = OrderGetDouble(ORDER_PRICE_OPEN);
            order["stoploss"] = OrderGetDouble(ORDER_SL);
            order["takeprofit"] = OrderGetDouble(ORDER_TP);
            order["volume"] = OrderGetDouble(ORDER_VOLUME_INITIAL);
      
            data["orders"].Add(order);
            
           }
         else        
           {
            // call OrderGetTicket() was completed unsuccessfully
            data["error"]= GetLastError();
            PrintFormat("Error when obtaining an order from the list to the cache. Error code: %d",GetLastError());
           }
        }
      }
    
    else
      {  
         // if no open orders  
         data["orders"].Add(0);
      }
    
    string t=data.Serialize();
    if(debug==true) {Print(t);}
    InformClientSocket(dataSocket,t);
    
    
  }

//+------------------------------------------------------------------+
//| Trading module                                                   |
//+------------------------------------------------------------------+
void TradingModule(Socket &dataSocket, CJAVal &dataObject)
  {

   string actionType = dataObject["actionType"].ToStr();

   if(actionType=="ORDER_TYPE_BUY" || actionType=="ORDER_TYPE_SELL")
     {
      ResetLastError();
      MqlTradeRequest order={0};
      MqlTradeResult  result={0};

      order.action=TRADE_ACTION_DEAL;
      order.symbol=dataObject["symbol"].ToStr();
      order.volume=dataObject["volume"].ToDbl();

      if(actionType=="ORDER_TYPE_BUY")
        {
         order.type=ORDER_TYPE_BUY;
         order.price=SymbolInfoDouble(symbol,SYMBOL_ASK);
        }
      else if(actionType=="ORDER_TYPE_SELL")
        {
         order.type=ORDER_TYPE_SELL;                         
         order.price=SymbolInfoDouble(symbol,SYMBOL_BID);
        }
      else Alert("Something wrong with market orders...");
      
      order.sl=dataObject["stoploss"].ToDbl();
      order.tp=dataObject["takeprofit"].ToDbl();
      order.deviation=dataObject["deviation"].ToInt();
      
      bool success=OrderSend(order,result); 
      if(!success) {InformClientSocket(dataSocket,StringFormat("OrderSend error %d",GetLastError()));}
      else {
         CJAVal conf;

         conf["retcode"] = (int) result.retcode;
         conf["deal"] = (string)result.deal;
         conf["order"] = "null";
         conf["volume"] = result.volume;
         conf["price"] = result.price;
         conf["bid"] = result.bid;
         conf["ask"] = result.ask;
         conf["comment"] = result.comment;
         
         string t=conf.Serialize();
         if(debug==true) { Print("Order conformation: "+t);}
         InformClientSocket(dataSocket,t);
       }
     }

   else if(actionType=="ORDER_TYPE_BUY_LIMIT" || actionType=="ORDER_TYPE_SELL_LIMIT" || actionType=="ORDER_TYPE_BUY_STOP" || actionType=="ORDER_TYPE_SELL_STOP")
     {
      
      ResetLastError();
      MqlTradeRequest order={0};
      MqlTradeResult  result={0};

      order.action=TRADE_ACTION_PENDING;
      order.symbol=dataObject["symbol"].ToStr();
      order.volume=dataObject["volume"].ToDbl();
      
      // setting order type
      if(actionType=="ORDER_TYPE_BUY_LIMIT") {order.type=ORDER_TYPE_BUY_LIMIT;}
      else if(actionType=="ORDER_TYPE_SELL_LIMIT"){order.type=ORDER_TYPE_SELL_LIMIT;}
      else if(actionType=="ORDER_TYPE_BUY_STOP"){order.type=ORDER_TYPE_BUY_STOP;}
      else if(actionType=="ORDER_TYPE_SELL_STOP"){order.type=ORDER_TYPE_SELL_STOP;}
      else Alert("Something wrong with pending orders...");
      
      order.price=NormalizeDouble(dataObject["price"].ToDbl(),_Digits);
      order.sl=dataObject["stoploss"].ToDbl();
      order.tp=dataObject["takeprofit"].ToDbl();
      order.deviation=dataObject["deviation"].ToInt();
      order.type_time=ORDER_TIME_DAY;
      order.type_filling=ORDER_FILLING_RETURN;
      
      bool success=OrderSend(order,result); 
      if(!success) {InformClientSocket(dataSocket,StringFormat("OrderSend error %d",GetLastError()));}
      else {
         CJAVal conf;

         conf["retcode"] = (int) result.retcode;
         conf["deal"] = "null";
         conf["order"] = (string)result.order;
         conf["volume"] = result.volume;
         conf["price"] = result.price;
         conf["bid"] = result.bid;
         conf["ask"] = result.ask;
         conf["comment"] = result.comment;
         
         string t=conf.Serialize();
         if(debug==true) { Print("Order conformation: "+t);}
         InformClientSocket(dataSocket,t);
       }
     }
     
   else if(actionType=="CLOSE_POSITION")
     {
      
      ResetLastError();
      MqlTradeRequest order={0};
      MqlTradeResult  result={0};

      order.action=TRADE_ACTION_PENDING;
      order.symbol=dataObject["symbol"].ToStr();
      order.volume=dataObject["volume"].ToDbl();
      
      // setting order type
      if(actionType=="ORDER_TYPE_BUY_LIMIT") {order.type=ORDER_TYPE_BUY_LIMIT;}
      else if(actionType=="ORDER_TYPE_SELL_LIMIT"){order.type=ORDER_TYPE_SELL_LIMIT;}
      else if(actionType=="ORDER_TYPE_BUY_STOP"){order.type=ORDER_TYPE_BUY_STOP;}
      else if(actionType=="ORDER_TYPE_SELL_STOP"){order.type=ORDER_TYPE_SELL_STOP;}
      else Alert("Something wrong with pending orders...");
      
      order.price=NormalizeDouble(dataObject["price"].ToDbl(),_Digits);
      order.sl=dataObject["stoploss"].ToDbl();
      order.tp=dataObject["takeprofit"].ToDbl();
      order.deviation=dataObject["deviation"].ToInt();
      order.type_time=ORDER_TIME_DAY;
      order.type_filling=ORDER_FILLING_RETURN;
      
      bool success=OrderSend(order,result); 
      if(!success) {InformClientSocket(dataSocket,StringFormat("OrderSend error %d",GetLastError()));}
      else {
         CJAVal conf;

         conf["retcode"] = (int) result.retcode;
         conf["deal"] = "null";
         conf["order"] = (string)result.order;
         conf["volume"] = result.volume;
         conf["price"] = result.price;
         conf["bid"] = result.bid;
         conf["ask"] = result.ask;
         conf["comment"] = result.comment;
         
         string t=conf.Serialize();
         if(debug==true) { Print("Order conformation: "+t);}
         InformClientSocket(dataSocket,t);
       }
     } 
  }

//+------------------------------------------------------------------+
//| Inform Client via socket                                         |
//+------------------------------------------------------------------+
void InformClientSocket(Socket &workingSocket,string replyMessage)
  {
   ZmqMsg pushReply(StringFormat("%s",replyMessage));
   
   // workingSocket.send(pushReply,false); // BLOCKING
   workingSocket.send(pushReply,true); // NON-BLOCKING                                   
  }
  
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
void OnTick()
  {

//+------------------------------------------------------------------+
//| Push candle on close to liveSocket                               |
//+------------------------------------------------------------------+
   datetime thisBar=(datetime)SeriesInfoInteger(symbol,period,SERIES_LASTBAR_DATE);
   
   if(lastBar!=thisBar)
     {
      MqlRates rates[1];
      CJAVal candle;

      if(CopyRates(symbol,period,1,1,rates)!=1) { /*error processing */ };
      
      candle[0] = (long) rates[0].time;
      candle[1] = (double) rates[0].open;
      candle[2] = (double) rates[0].high;
      candle[3] = (double) rates[0].low;
      candle[4] = (double) rates[0].close;
      candle[5] = (double) rates[0].tick_volume;
      
      string t=candle.Serialize();
      if(debug==true) 
         {
            PrintFormat("New candle: %s %s",TimeToString(rates[0].time), t);
         }
      InformClientSocket(liveSocket,t);

      lastBar=thisBar;
     }

  }
//+------------------------------------------------------------------+