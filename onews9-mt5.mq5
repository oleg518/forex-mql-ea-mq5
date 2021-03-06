//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2012, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
//--------------------------------------------------------------------
extern string o1="  ---------- ТРЕЙЛИНГ-СТОП --------------     ";
extern int     Dist=200;   //расстояние от цены
extern int     TrailingStop         = 40;     //длина тралла (0 - без тралла)
extern int     TSz                  = 10;     //задержка трейлинга в пунктах 
extern int     tttimer=100;     // тралл по таймеру в миллисекундах, если 0 - без тралла по таймеру

extern string o2="  ---------- СДВИГАНИЕ ОТЛОЖЕК ----------     ";
extern int     Stoploss=555;     //стоплосс, если 0 - то без него
extern int     TimeModify=1;     // Интервал сдвига отложек, сек
extern int     Kor=50;     //спокойный коридор, 0 - без него

extern string o3="  ---------- ЗАПУСК ПО ВРЕМЕНИ ----------     ";
extern datetime timeStart=D'15:29:50'; // Старт
extern datetime timeFinish=0; // Финиш (необязательно)

extern string o4="  ---------- РАЗНОЕ ---------------------     ";
extern double  Lot=0.01;  // объем лота
extern bool  tester=false;  // режим тестинга

bool deal_opened=false;
bool error;
bool local_time_corrected=false;
bool need_move_B=false,need_move_S=false,need_move_R=false;
bool old_start_time=false;
bool pending_closed=false;
bool pendings_placed=false;
bool print_stats=false;
bool stats_empty=true,stats_empty_written=false;
bool stats_printed=false;
color color_profit,color_rivok;
color TLclr=Lime;
datetime time_otst;
datetime time5sec=TimeLocal();
datetime TTouched;
double K1,K2;
double lastOOP,lastOOP_S,lastOOP_B;
double Minute_cur=round(TimeCurrent()/60)*60;
double order_close_slippage_int;
double order_open_slippage_int;
double order_profit_dbl;
double order_profit_p_int;
double OSL,OOP,SL,lastSL;
double rivok0,rivok;
double SL0=0;
double Spread=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD)*_Point;
long STOPLEVEL;
double TSsum=0;
int sign_order=0;
int slippage=250;
int oi=2,oi1=2;
int otstup_level,otstup_level1;
int otstup_right=5;
int otstup_up=30,otstup_up1=16;;
int otstup_up0=24,otstup_up01=30;
int font_size=14,font_size1=10,font_size_text_=16;
int ii=0, iit=0, iic=0, in_tick=1,in_timer=2;
long OT;
int otst=1;
int sign_slip;
int str_pos=0;
int tick_count=0;
int ttimer;
long chart_ID=ChartID();
long time_left,secs_left,mins_left,hours_left,days_left,mnths_left,yrs_left;
string hor_line_1="hor_line_1";
string hor_line_2="hor_line_2";
string order_close_slippage="order_close_slippage";
string order_open_slippage="order_open_slippage";
string order_profit_p="order_profit_p";
string order_profit="order_profit";
string Rect1="Rect1";
string server_time="server_time";
string tick_or_timer_str;
string time_curr="time_curr";
string time_gone_str;
string time_left_hms;
string time_left_str_text="time_left_str_text";
string TimeFinishEv="TimeFinishEv";
string TimeStartEv="TimeStartEv";
string vert_line_curr="vert_line_curr";
string vert_line_finish="vert_line_finish";
string vert_line_start="vert_line_start";
uint tral_start, otladka_start;
string sov_pars1_str,sov_pars2_str;
string stats_empty2str;
string time_left_strstr;

MqlTick last_tick;
double Ask, Bid;
string current_symbol=_Symbol;
ulong ticketN, dealN, zdealN, horderN;
CTrade *Trade;
CPositionInfo PositionInfo;
MqlDateTime  dt_struct;



////////////////////////////+------------------------------------------------------------------+
////////////////////////////|                   НАЧАЛО ИНИЦИАЛИЗАЦИИ                           |
////////////////////////////+------------------------------------------------------------------+
int OnInit()
  {
   Print("============= Инициация советника ========== время: ",TimeCurrent()," ========");
   Print("Spread = ",round(Spread/_Point));
   Print("TimeLocal = ",TimeLocal(dt_struct));
   Print("TimeCurrent = ",TimeCurrent());

   if(tester)
     {
      timeStart=TimeCurrent()+5;         // для тестера
      timeFinish=TimeCurrent()+12*60*60;
     }

//Print(AccountInfoInteger(ENUM_ACCOUNT_TRADE_MODE),"------------"); //if (AccountInfoString(ENUM_ACCOUNT_TRADE_MODE)==ENUM_ACCOUNT_TRADE_DEMO) Print("DEMOOOOOOOOOOOOO");

/*  if(timeStart<=TimeCurrent())
     {
      old_start_time=true;
      create_text("error timeStart<=TimeCurrent","Задано старое время, остановка.",Red);
      timeFinish=TimeCurrent();
     }*/


   if(tttimer==0) ttimer=1000; else ttimer=tttimer;
   EventSetMillisecondTimer(ttimer);

   if(timeFinish<timeStart) timeFinish=timeStart+2*60;

   Minute_cur=round(TimeCurrent()/60)*60;
   
   Trade = new CTrade;
	Trade.SetDeviationInPoints(slippage);


   if(SymbolInfoTick(Symbol(),last_tick)) {Ask=last_tick.ask; Bid=last_tick.bid; }
   
   create_event(TimeStartEv,timeStart,Black);
   create_event(TimeFinishEv,timeFinish,Black);
   create_event(time_curr,TimeCurrent(),MidnightBlue);
   create_v_line(vert_line_start,timeStart,Blue,STYLE_DOT);
   create_v_line(vert_line_finish,timeFinish,Blue,STYLE_DOT);
   create_h_line(hor_line_1,Ask+Dist*_Point,DarkSlateGray,STYLE_DASH);
   create_h_line(hor_line_2,Bid-Dist*_Point,DarkSlateGray,STYLE_DASH);



   K1=Ask+Kor*_Point;
   K2=Bid-Kor*_Point;
   create_rect(Rect1,TimeCurrent()+60*5,K1,TimeCurrent()-60*5,K2,MidnightBlue);

   oi=oi-2;
   oi1=oi1-2;
   create_text(server_time,"",White);
   create_text(time_left_str_text,TimeLeftCount(),Lime);

   if(Spread>=Stoploss*_Point && !Spread==0)
     {
      int oldSLch=Stoploss;
      Stoploss=(int)round(Spread*1.25/_Point);
      Print("Старый СЛ=",oldSLch," изменен на ",Stoploss);
     }

   StringConcatenate(sov_pars1_str,"Dist=",Dist,", TS=",TrailingStop,"+",TSz,", SL=",Stoploss,", TM=",TimeModify,"s, Kor=",Kor,", Lot=",Lot);
   create_text1("sov_pars1",sov_pars1_str,DarkGray);
   StringConcatenate(sov_pars2_str,"Begin ",timeStart,", Finish ",timeFinish,"");
   create_text1("sov_pars2",sov_pars2_str,DarkGray);

   oi--;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if (tester) CloseSel();
  }
////////////////////////////+------------------------------------------------------------------+
////////////////////////////|                    КОНЕЦ ИНИЦИАЛИЗАЦИИ                           |
////////////////////////////+------------------------------------------------------------------+







////////////////////////////+------------------------------------------------------------------+
////////////////////////////|                    НАЧАЛО ТИКА                                   |
////////////////////////////+------------------------------------------------------------------+

void OnTick()
  {
  
  if(SymbolInfoTick(Symbol(),last_tick)) {Ask=last_tick.ask; Bid=last_tick.bid; }

  
 /* Print("K1 = ",K1);
  Print("K2 = ",K2);
  Print("Ask = ",Ask);
  Print("Bid = ",Bid);*/
   if((TimeCurrent()>timeStart && TimeCurrent()<timeFinish))
     {
         
      STOPLEVEL=(SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL));
      OSL=0;
      OOP=0;
      SL=0;


      TRAILING(in_tick);

      if(need_move_R)
        {
         need_move_B=true;
         need_move_S=true;
        }

      //+------------------------------------------------------------------+
      //|                     ТРАЛ                                         |
      //+------------------------------------------------------------------+

      for(ii=0; ii<OrdersTotal(); ii++)
        {
               
        ticketN=OrderGetTicket(ii);
         if(OrderSelect(ticketN))
           {
            if(OrderGetString(ORDER_SYMBOL)==current_symbol)
              {
               //+------------------------------------------------------------------+
               //|                     ПЕРЕДВИЖКА ОТЛОЖЕК                           |
               //+------------------------------------------------------------------+

               if(!deal_opened)
                 {
                  if((TimeCurrent()>TTouched+TimeModify) && (need_move_B || need_move_S))
                    {   
                    OT=OrderGetInteger(ORDER_TYPE);              
                     if(OT==ORDER_TYPE_BUY_STOP)
                       {
                        if(Stoploss>=STOPLEVEL && Stoploss!=0) SL=NormalizeDouble(Ask+(Dist-Stoploss)*_Point,_Digits); else SL=0;
                        if(need_move_B)
                          {
                           otladka_start=GetTickCount();
                           if(Trade.OrderModify(ticketN,NormalizeDouble(Ask+Dist*_Point,_Digits),SL,ORDER_TIME_GTC,0,0))
                             {
                              Print("Buy stop передвинута на уровень ",Ask+Dist*_Point," за ",GetTickCount()-otladka_start," мс"); 
                              lastOOP_B=NormalizeDouble(Ask+Dist*_Point,_Digits);
                              need_move_B=false;
                              MoveRect();
                              // rivok0=(Ask+Bid)/2;
                             }
                          }
                       }

                     if(OT==ORDER_TYPE_SELL_STOP)
                       {
                        if(Stoploss>=STOPLEVEL && Stoploss!=0) SL=NormalizeDouble(Bid-(Dist-Stoploss)*_Point,_Digits); else SL=0;
                        if(need_move_S)
                          {
                           otladka_start=GetTickCount();
                           if(Trade.OrderModify(ticketN,NormalizeDouble(Bid-Dist*_Point,_Digits),SL,ORDER_TIME_GTC,0,0))
                             {
                              Print("Sell stop передвинута на уровень ",Bid-Dist*_Point," за ",GetTickCount()-otladka_start," мс"); 
                              lastOOP_S=NormalizeDouble(Bid-Dist*_Point,_Digits);
                              need_move_S=false;
                              MoveRect();
                              //rivok0=(Ask+Bid)/2;
                             }
                          }
                       }

                    }

                 }

              }
           }
        }


      //+------------------------------------------------------------------+
      //|   ОТКРЫТИЕ ОРДЕРА БС/СС, ЕСЛИ ТАКИХ НЕТУ НА ДАННЫЙ МОМЕНТ        |
      //+------------------------------------------------------------------+


      if(!pendings_placed && TimeCurrent()>=timeStart && TimeCurrent()<timeFinish)
        {
         Print("Отложки выставлены по ТИКУ");
         place_pendings();
        }

     }

   if(!deal_opened)
     {

      if(TimeCurrent()<timeFinish)
        {

         if(TimeCurrent()-60>Minute_cur)
           {
            error=(ObjectMove(chart_ID,Rect1,0,TimeCurrent()+5*60,K1) && ObjectMove(chart_ID,Rect1,1,TimeCurrent()-5*60,K2));
            error=ObjectMove(chart_ID,time_curr,0,TimeCurrent(),0);
            Minute_cur=round(TimeCurrent()/60)*60;
           }

         if(Ask>K1 || Bid<K2)
           {
            if(!need_move_R)
              {
               need_move_R=true;
               TTouched=TimeCurrent();
              }
           }

         if((TimeCurrent()>TTouched+TimeModify) && (need_move_R))
           {

            if(TimeCurrent()<timeStart)
              {
               MoveRect();
               error=ObjectMove(chart_ID,hor_line_1,0,0,Ask+Dist*_Point);
               error=ObjectMove(chart_ID,hor_line_2,0,0,Bid-Dist*_Point);
              }

            need_move_R=false;

           }

        }

     }

   if(!local_time_corrected)
     {
      if(TimeLocal()>TimeCurrent()) otst=-1;
      time_otst=otst*(TimeCurrent()-TimeLocal());         // time_otst=TimeCurrent()-otst*TimeLocal();

      Print("time_otst = ",time_otst," , otst=",otst);
      local_time_corrected=true;
     }

   //if(print_stats && OrdersTotal()==0) if_ended_text_stats();

  // if (deal_opened && tick_count<20) tick_count++;

   if(TimeCurrent()>=timeFinish)
     {
      CloseSel();
     }
  }
////////////////////////////+------------------------------------------------------------------+
////////////////////////////|                     КОНЕЦ ТИКА                                   |
////////////////////////////+------------------------------------------------------------------+










////////////////////////////+------------------------------------------------------------------+
////////////////////////////|                    НАЧАЛО ТАЙМЕРА                                |
////////////////////////////+------------------------------------------------------------------+


void OnTimer()
  {

    if(tttimer>0 && (TimeCurrent()>timeStart && TimeCurrent()<timeFinish))
     {
    if(SymbolInfoTick(Symbol(),last_tick)) {Ask=last_tick.ask; Bid=last_tick.bid; }

     
     
      STOPLEVEL=(SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL));
      OSL=0;
      OOP=0;
      SL=0;
       
      TRAILING(in_timer);
      
       
     }

   if(!pendings_placed && TimeLocal()+otst*time_otst>=timeStart && TimeCurrent()<timeFinish)
     {
      place_pendings();
      Print("Отложки выставлены по ТАЙМЕРУ");
      //rivok0=(Ask+Bid)/2;
     }

   if(TimeLocal()>time5sec+5 && print_stats && !stats_printed)
     {
     Print("Print stats...");
      time5sec=TimeLocal();
      if_ended_text_stats();
     }

   if(TimeCurrent()>timeFinish && stats_empty && !stats_empty_written)
     {
      create_text("stats_empty1","Время прошло, отложки так и не сработали",White);
      StringConcatenate(stats_empty2str,timeStart," - ",timeFinish);
      create_text("stats_empty2",stats_empty2str,White);
      stats_empty_written=true;
     }

   ObjectSetString(chart_ID,time_left_str_text,OBJPROP_TEXT,TimeLeftCount());
   ObjectSetInteger(chart_ID,time_left_str_text,OBJPROP_COLOR,TLclr);
   ObjectSetString(chart_ID,server_time,OBJPROP_TEXT,TimeToString(TimeLocal()+otst*time_otst,TIME_SECONDS));
  
      //ObjectSetString(chart_ID,server_time,OBJPROP_TEXT,GetMicrosecondCount());
   
/* if(pendings_placed)
     {
      time_gone_str=StringConcatenate("Прошло ",TimeToStr(TimeLocal()+otst*time_otst-timeStart,TIME_SECONDS));
      ObjectSetString(chart_ID,time_left_str_text,OBJPROP_TEXT,time_gone_str);
      ObjectSetInteger(chart_ID,time_left_str_text,OBJPROP_COLOR,Yellow);
     // time_gone_str_placed=true;
     }*/

   if(pendings_placed && ObjectFind(0,time_left_str_text)!=-1)
     {
      error=ObjectDelete(chart_ID,time_left_str_text);
     }
   ChartRedraw(0);
  }
////////////////////////////+------------------------------------------------------------------+
////////////////////////////|                    КОНЕЦ ТАЙМЕРА                                 |
////////////////////////////+------------------------------------------------------------------+









////////////////////////////+------------------------------------------------------------------+
////////////////////////////|                     ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (начало)             |
////////////////////////////+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//|                     CloseSel и CloseSeli                         |
//+------------------------------------------------------------------+



void CloseSel() // <0 - значит закрыть все
  {
   for(iic=0; iic<OrdersTotal(); iic++)
     {
              ticketN=OrderGetTicket(iic);
      if(OrderGetString(ORDER_SYMBOL)==current_symbol)
        {
         OT=OrderGetInteger(ORDER_TYPE);
         Print("Закрытие оставшейся отложки...");  
         otladka_start=GetTickCount();
          if(Trade.OrderDelete(ticketN)) Print("Отложка № ",ticketN," закрыта за ",GetTickCount()-otladka_start," мс");
        }
     }
  


   /*for(iic=0; iic<PositionsTotal(); iic++)    // зачем закрывать позицию - не нужно
     {
      if(PositionGetString(POSITION_SYMBOL)==current_symbol)
        {
        ticketN=PositionGetTicket(iic);
         if(!(iic==not_delete_i))
           {
            OT=PositionGetInteger(POSITION_TYPE);

            if (Trade.PositionClose(current_symbol,ticketN)) { pending_closed=true;
           }
        }
     }*/
    }




/*


void CloseSel(int orderN) // <0 - значит закрыть все
  {
   for(i=0; i<OrdersTotal(); i++)
     {
      if(OrderGetString(ORDER_SYMBOL)==current_symbol)
        {
         ticketN=OrderGetTicket(i);
         if(OrderSelect(ticketN) && !(i==orderN))
           {
           OT  = OrderGetInteger(ORDER_TYPE);
            if(OT==ORDER_TYPE_BUY)  error=OrderClose(OrderTicket(), OrderLots(), MarketInfo(current_symbol, MODE_BID), slippage, CLR_NONE);
            if(OT==ORDER_TYPE_SELL) error=OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), slippage, CLR_NONE);
            if(OT==ORDER_TYPE_BUY_LIMIT || OT==ORDER_TYPE_BUY_STOP || OT==ORDER_TYPE_SELL_LIMIT || OT==ORDER_TYPE_SELL_STOP)
            {
            otladka_start=GetTickCount();
            if (OrderDelete(OrderTicket()))
            {
            Print("Отложка № ",OrderTicket()," закрыта за ",GetTickCount()-otladka_start," мс"); 
            }
            }
           }
        }
     }
   if(ObjectFind(0,Rect1)!=-1) error=ObjectDelete(chart_ID,Rect1); 
   if(ObjectFind(0,time_left_str_text)!=-1 && orderN==-1) error=ObjectDelete(chart_ID,time_left_str_text);
  }
  
  */
  
  /*
void CloseSeli()
{
if (!pending_closed)
{
      Print("Закрытие оставшейся отложки...");  
      CloseSel(ii); // if (tick_count>2)  закрыть все кроме этого ордера
      //Print("Отложка закрыта");
      pending_closed=true;
}
}  */
  
  
//+------------------------------------------------------------------+
//|                       TRAILING                                   |
//+------------------------------------------------------------------+
void TRAILING(int tick_or_timer)
  {
   if(tick_or_timer==in_tick) tick_or_timer_str="ТИК"; else tick_or_timer_str="ТАЙМЕР";

      for(iit=0; iit<PositionsTotal(); iit++)
        {
        ticketN=PositionGetTicket(iit);
         if(PositionGetString(POSITION_SYMBOL)==current_symbol)
           {
            
               OT  = PositionGetInteger(POSITION_TYPE);
               OSL = PositionGetDouble(POSITION_SL);
               OOP = PositionGetDouble(POSITION_PRICE_OPEN);
               lastSL=OSL;
               
   if(OT==POSITION_TYPE_BUY) sign_order=1;
   if(OT==POSITION_TYPE_SELL) sign_order=-1;

   SL=OSL;
   
   if(OT==POSITION_TYPE_BUY || OT==POSITION_TYPE_SELL)
     {
         deal_opened=true;
      if(OT==POSITION_TYPE_BUY) SL=Bid-TrailingStop*_Point; else SL=Ask+TrailingStop*_Point;

      if(sign_order*(SL-OSL)>TSz*_Point)
        {
        if (SL0==0) SL0=OSL; 
         Print("Команда траллить!");
         tral_start=GetTickCount();
         if(Trade.PositionModify(ticketN,SL,0))
           {
            lastSL=SL;
            TSsum=TSsum+sign_order*(SL-OSL);
            Print("СЛ сдвинулся по ",tick_or_timer_str,"У на ",round(sign_order*(SL-OSL)/_Point)," пп , интервал сдвига ",GetTickCount()-tral_start," мс");
           }
        }
      CloseSel(); // возможно нужно перенести в момент открытия статистики
      if (!stats_printed) print_stats=true;
      time5sec=TimeLocal();
     }
     }
     }
  }
//+------------------------------------------------------------------+
//|                     MoveRect                                     |
//+------------------------------------------------------------------+



void MoveRect()
  {
   K1=Ask+Kor*_Point;
   K2=Bid-Kor*_Point;
   error=ObjectMove(chart_ID,Rect1,0,TimeCurrent()+5*60,K1) && ObjectMove(chart_ID,Rect1,1,TimeCurrent()-5*60,K2);
  }
//+------------------------------------------------------------------+
//|                     place_pendings                               |
///+------------------------------------------------------------------+


void place_pendings()
  {
   STOPLEVEL=(SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL));
   SL=0;

   if(Stoploss>=STOPLEVEL && Stoploss!=0) SL=Ask+(Dist-Stoploss)*_Point; else SL=0;
   
   
   otladka_start=GetTickCount();      
   if(Trade.OrderOpen(Symbol(),ORDER_TYPE_BUY_STOP,Lot,0,Ask+Dist*_Point,SL,0,0,0))
     {
      Print("Buy stop выставлена на уровень ",Ask+Dist*_Point," за ",GetTickCount()-otladka_start," мс");   
      lastOOP_B=Ask+Dist*_Point;
      MoveRect();
     }

   if(Stoploss>=STOPLEVEL && Stoploss!=0) SL=Bid-(Dist-Stoploss)*_Point; else SL=0;
   otladka_start=GetTickCount();  
   if(Trade.OrderOpen(Symbol(),ORDER_TYPE_SELL_STOP,Lot,0,Bid-Dist*_Point,SL,0,0,0))
     {
      Print("Sell stop выставлена на уровень ",Bid-Dist*_Point," за ",GetTickCount()-otladka_start," мс"); 
      lastOOP_S=Bid-Dist*_Point;
      MoveRect();
     }

   if(ObjectFind(0,hor_line_1)!=-1) error=ObjectDelete(chart_ID,hor_line_1);
   if(ObjectFind(0,hor_line_2)!=-1) error=ObjectDelete(chart_ID,hor_line_2);
//rivok0=(Ask+Bid)/2;
   pendings_placed=true;
  }
//+------------------------------------------------------------------+
//|                     create_text (верхний)                        |
//+------------------------------------------------------------------+


void create_text(string name,string text,int clr)
  {
   otstup_level=otstup_up0+oi*otstup_up;

   ObjectCreate(chart_ID,name,OBJ_LABEL,0,0,0);

//--- установим способ привязки

   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);

//--- установим текст события

   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);

//--- установим цвет

   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);

//--- отобразим на переднем (false) или заднем (true) плане

   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,true);

//--- скроем (true) или отобразим (false) имя графического объекта в списке объектов

   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,false);

//--- установим координаты метки

   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,otstup_right);

   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,otstup_level);

//--- установим угол графика, относительно которого будут определяться координаты точки

   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);

//--- установим шрифт текста

   ObjectSetString(chart_ID,name,OBJPROP_FONT,"Calibri");

//--- установим размер шрифта

   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size);
   oi++;
  }
//+------------------------------------------------------------------+
//|                     create_text (нижний)                         |
//+------------------------------------------------------------------+


void create_text1(string name,string text,int clr)
  {
   otstup_level1=otstup_up01+oi1*otstup_up1;
   ObjectCreate(chart_ID,name,OBJ_LABEL,0,0,0);

//--- установим способ привязки

   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);

//--- установим текст события

   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);

//--- установим цвет

   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);

//--- отобразим на переднем (false) или заднем (true) плане

   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,true);

//--- скроем (true) или отобразим (false) имя графического объекта в списке объектов

   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,false);

//--- установим координаты метки

   ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,otstup_right);

   ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,otstup_level1);

//--- установим угол графика, относительно которого будут определяться координаты точки

   ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,CORNER_RIGHT_LOWER);

//--- установим шрифт текста

   ObjectSetString(chart_ID,name,OBJPROP_FONT,"Calibri");

//--- установим размер шрифта

   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size1);
   oi1++;
  }
//+------------------------------------------------------------------+
//|     string TimeLeftCount (строка с оставшимся временем)          |
//+------------------------------------------------------------------+


string TimeLeftCount()      // попробовать  TimeTradeServer
  {
   time_left=timeStart-(TimeLocal()+otst*time_otst);
   
   days_left=time_left/(24*60*60);
   hours_left=(time_left/(60*60))-days_left*24;
   mins_left=(time_left/60)-days_left*24*60-hours_left*60;
   secs_left=time_left-days_left*24*60*60-hours_left*60*60-mins_left*60;
   
   if(time_left<60) TLclr=Yellow; else TLclr=Lime;

   if (time_left/(24*60*60)>=1) StringConcatenate(time_left_strstr,"Отложки через ",days_left," дн ",hours_left," ч ",mins_left," мин ",secs_left);
   if (time_left/(60*60)>=1 && time_left/(24*60*60)<1) StringConcatenate(time_left_strstr,"Отложки через ",hours_left," ч ",mins_left," мин ",secs_left);
   if (time_left/60>=1 && time_left/(60*60)<1) StringConcatenate(time_left_strstr,"Отложки через ",mins_left," мин ",secs_left);
   if (time_left/60<1) StringConcatenate(time_left_strstr,"Отложки через ",secs_left);
   
   //StringReplace(time_left_strstr,".0","");
   string time_left_str=time_left_strstr;
   return time_left_str;
  }
//+------------------------------------------------------------------+
//|                    if_ended_text_stats                           |
//+------------------------------------------------------------------+


void if_ended_text_stats()
  {
  if (!stats_printed)
  {
  error=HistorySelect(timeStart,timeFinish);
 // CloseSeli();
 ticketN=0;
   for(ii=0; ii<HistoryDealsTotal(); ii++)
     {
     ticketN=HistoryDealGetTicket(ii);
     OT=HistoryDealGetInteger(ticketN,DEAL_TYPE);
      if(HistoryDealGetString(ticketN,DEAL_SYMBOL)==current_symbol)
      {
      if (OT==DEAL_TYPE_BUY || OT==DEAL_TYPE_SELL)
      {
      if (HistoryDealGetInteger(ticketN,DEAL_ENTRY)==DEAL_ENTRY_IN) dealN=ticketN; else zdealN=ticketN;
      }
      
      
      }
     }
     
     
     
      /*  for(i=0; i<HistoryOrdersTotal(); i++)
     {
     ticketN=HistoryOrderGetTicket(i);
     OT=HistoryOrderGetInteger(ticketN,ORDER_TYPE);
      if(HistoryOrderGetString(ticketN,ORDER_SYMBOL)==current_symbol && (OT==ORDER_TYPE_BUY || OT==ORDER_TYPE_SELL))
                 {
      horderN=HistoryOrderGetTicket(i);
      }
     }
     */
     
                  
                  stats_empty=false;
                  OT=HistoryDealGetInteger(dealN,DEAL_TYPE);
                  OOP=HistoryDealGetDouble(dealN,DEAL_PRICE);
                  double OCP=HistoryDealGetDouble(zdealN,DEAL_PRICE);
                  horderN=HistoryDealGetInteger(dealN,DEAL_ORDER);
                  //Print("horderN = ",horderN);
                  lastOOP=HistoryOrderGetDouble(horderN,ORDER_PRICE_OPEN);
                  //SL=HistoryOrderGetDouble(horderN,ORDER_SL);
                  SL=lastSL;
                  
                 
                  string order_history_ticket_str;
                  StringConcatenate(order_history_ticket_str,"Тикет ордера ",dealN);
                  create_text("order_history_ticket",order_history_ticket_str,DodgerBlue);
                  
                  double deal_lot=HistoryDealGetDouble(dealN,DEAL_VOLUME);
                  string create_textstr;
                  if(OT==DEAL_TYPE_BUY)
                    {
                     //lastOOP=lastOOP_B;
                     sign_slip=1;
                     StringConcatenate(create_textstr,"Покупка объемом ",deal_lot," лота");
                     create_text("pokupka",create_textstr,DodgerBlue);
                     // color_rivok=Lime;
                    }

                  if(OT==DEAL_TYPE_SELL)
                    {
                     //lastOOP=lastOOP_S;
                     sign_slip=-1;
                     StringConcatenate(create_textstr,"Продажа объемом ",deal_lot," лота");
                     create_text("prodazha",create_textstr,DodgerBlue);
                     //color_rivok=Red;
                    }

                  //rivok0=rivok0+sign_slip*Spread/2;

                  long hOOT=HistoryDealGetInteger(dealN,DEAL_TIME),hOCT=HistoryDealGetInteger(zdealN,DEAL_TIME);
                  //Print("zdealN = ",zdealN);
                  
                  
                  string order_time_openstr;
                  StringConcatenate(order_time_openstr,"Открытие ордера в ",TimeToString(hOOT,TIME_SECONDS));
                  create_text("order_time_open",order_time_openstr,DodgerBlue);
                  string order_time_closestr;
                  StringConcatenate(order_time_closestr,"Закрытие ордера в ",TimeToString(hOCT,TIME_SECONDS));
                  create_text("order_time_close",order_time_closestr,DodgerBlue);

                  // if (sign_slip==1) rivok=round((iHigh(Symbol(),PERIOD_M1,0)-rivok0)/_Point); else rivok=round((rivok0-iLow(Symbol(),PERIOD_M1,0))/_Point);
                  //create_text("rivok",StringConcatenate("Рывок ",rivok),White);

                  order_open_slippage_int=round(sign_slip*(OOP-lastOOP)/_Point);
                  string order_open_slippagestr;
                  StringConcatenate(order_open_slippagestr,"Проскальзывание на открытии ",order_open_slippage_int);
                  StringReplace(order_open_slippagestr,".0",""); 
                  create_text(order_open_slippage,order_open_slippagestr,Yellow);

                  order_close_slippage_int=round(sign_slip*(SL-OCP)/_Point);
                  string order_close_slippagestr;
                  StringConcatenate(order_close_slippagestr,"Проскальзывание на закрытии ",order_close_slippage_int);
                  StringReplace(order_close_slippagestr,".0",""); 
                  create_text(order_close_slippage,order_close_slippagestr,DarkOrange);
                  string TSsum_pointsstr;
                  StringConcatenate(TSsum_pointsstr,"Общее движение СЛ ",round(TSsum/_Point));
                  StringReplace(TSsum_pointsstr,".0",""); 
                  create_text("TSsum_points",TSsum_pointsstr,White);

                  order_profit_p_int=round(sign_slip*(OCP-OOP)/_Point);

                  if(order_profit_p_int>=0) color_profit=Lime; else color_profit=Red;
                  string order_profit_pstr;
                  StringConcatenate(order_profit_pstr,"Профит ",order_profit_p_int);
                  StringReplace(order_profit_pstr,".0",""); 
                  create_text(order_profit_p,order_profit_pstr,color_profit);
                  string order_profitstr;
                  StringConcatenate(order_profitstr,"Профит ",HistoryDealGetDouble(zdealN,DEAL_PROFIT)," руб.");
                  create_text(order_profit,order_profitstr,color_profit);

                  create_tria("Open_tria",hOOT,lastOOP,hOOT+2*60,lastOOP,hOOT,OOP,Yellow,1);
                  create_tria("Close_tria",hOCT,SL,hOCT+2*60,SL,hOCT,OCP,DarkOrange,1);
                  create_tria("Profit_tria",hOOT,OOP,hOOT+60,OOP,hOCT,OCP,DodgerBlue,1);
                  //create_tria("moving_SL_tria",hOOT,SL0,hOOT+60,SL0,hOCT,OrderStopLoss(),DimGray,1);

                  //  create_rect("order_open_slippage_rect",OrderOpenTime(),lastOOP,OrderCloseTime()-5*60,OrderOpenPrice(),DarkOrange);
                  //  create_rect("order_profit_rect",OrderOpenTime(),OrderOpenPrice(),OrderCloseTime()-5*60,OrderClosePrice(),Blue);                
                  //  create_rect("order_close_slippage_rect",OrderOpenTime(),OrderStopLoss(),OrderCloseTime()-5*60,OrderClosePrice(),Yellow);

                  // create_arrow("order_rivok_arrow",OrderOpenTime()-5*60,lastOOP,White);
                  // create_rect("rivok_rect",OrderOpenTime()-6*60,NormalizeDouble(rivok0,_Digits),OrderCloseTime()-5*60,rivok0+sign_slip*rivok*_Point,color_rivok);
                  // create_tria("rivok_tria",OrderOpenTime()-6*60,rivok0+_Point,OrderOpenTime()-6*60,rivok0+sign_slip*rivok*_Point,OrderOpenTime()-8*60,rivok0+_Point,color_rivok);

                  // create_text_("rivok_points",StringConcatenate(round(rivok)),OrderOpenTime()-6*60,rivok0+rivok*_Point/2,White);
                  // create_text_("order_open_slippage_points",StringConcatenate("пр.откр. ",round(order_open_slippage_int)),OrderOpenTime()-3*60,(lastOOP+OrderOpenPrice())/2,White);
                  // create_text_("order_profit_p_int",StringConcatenate("профит ",round(order_profit_p_int)),OrderOpenTime()-3*60,(OrderOpenPrice()+OrderClosePrice())/2,White);
                  // create_text_("order_close_slippage_points",StringConcatenate("пр.закр. ",round(order_close_slippage_int)),OrderOpenTime()-3*60,(OrderClosePrice()+OrderStopLoss())/2,White);
                  string print_statsstr;
                  StringConcatenate(print_statsstr,"Dist=",Dist,", TS=",TrailingStop,"+",TSz,", SL=",Stoploss,", TM=",TimeModify,"s, Kor=",Kor,", Lot=",Lot);
                  Print(print_statsstr);
                  
                  print_stats=false;
                  stats_printed=true;
                  
               
              
          
        
     
   }
  }
//+------------------------------------------------------------------+
//|                           create_event                           |
//+------------------------------------------------------------------+


void create_event(string name,datetime time_ev,color color_ev)
  {
   error=ObjectCreate(chart_ID,name,OBJ_EVENT,0,time_ev,0);
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,true);
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,color_ev);
   ObjectMove(chart_ID,name,0,time_ev,0);
  }
//+------------------------------------------------------------------+
//|                           create_v_line                          |
//+------------------------------------------------------------------+

void create_v_line(string name,datetime time_l,color color_l,int style_l)
  {

   error=ObjectCreate(chart_ID,name,OBJ_VLINE,0,time_l,0);
//--- установим цвет линии
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,Blue);
//--- установим стиль отображения линии
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style_l);
//--- установим толщину линии
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,1);
//--- отобразим на переднем (false) или заднем (true) плане
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,true);
   ObjectMove(chart_ID,name,0,time_l,0);
  }
//+------------------------------------------------------------------+
//|                           create_h_line                          |
//+------------------------------------------------------------------+
void create_h_line(string name,double price_l,color color_l,int style_l)
  {
   error=ObjectCreate(chart_ID,name,OBJ_HLINE,0,0,price_l);
//--- установим цвет линии
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,color_l);
//--- установим стиль отображения линии
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style_l);
//--- установим толщину линии
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,1);
//--- отобразим на переднем (false) или заднем (true) плане
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,true);
   ObjectMove(chart_ID,name,0,0,price_l);
  }
//+------------------------------------------------------------------+
//|                           create_rect                            |
//+------------------------------------------------------------------+
void create_rect(string name,datetime time1,double price1,datetime time2,double price2,color color_r)
  {
   error=ObjectCreate(chart_ID,name,OBJ_RECTANGLE,0,time1,price1,time2,price2);
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,color_r);
//--- отобразим на переднем (false) или заднем (true) плане
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,true);
      ObjectSetInteger(chart_ID,name,OBJPROP_FILL,true); 
  }
//+------------------------------------------------------------------+
//|                          create_tria                             |
//+------------------------------------------------------------------+
void create_tria(string name,datetime time1,double price1,datetime time2,double price2,datetime time3,double price3,color color_t,int width)
  {

   error=ObjectCreate(chart_ID,name,OBJ_TRIANGLE,0,time1,price1,time2,price2,time3,price3);

//--- установим цвет треугольника

   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,color_t);

//--- установим стиль линий треугольника

   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,STYLE_SOLID);

//--- установим толщину линий треугольника

   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);

//--- отобразим на переднем (false) или заднем (true) плане

   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,false);

//--- включим (true) или отключим (false) режим выделения треугольник для перемещений

//--- при создании графического объекта функцией ObjectCreate, по умолчанию объект

//--- нельзя выделить и перемещать. Внутри же этого метода параметр selection

//--- по умолчанию равен true, что позволяет выделять и перемещать этот объект

   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,true);

   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,false);

//--- скроем (true) или отобразим (false) имя графического объекта в списке объектов

   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,false);

   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,false);

   ObjectSetInteger(chart_ID,name,OBJPROP_FILL,true);

  }
//+------------------------------------------------------------------+
//|                       create_arrow                               |
//+------------------------------------------------------------------+
void create_arrow(string name,datetime time,double price,color clr)
  {

   if(sign_slip==1) error=ObjectCreate(chart_ID,name,OBJ_ARROW_UP,0,time,price);
   if(sign_slip==-1) error=ObjectCreate(chart_ID,name,OBJ_ARROW_DOWN,0,time,price);

   if(!rivok==0)
     {

      //--- установим способ привязки

      if(sign_slip==1) ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,ANCHOR_BOTTOM);
      if(sign_slip==-1) ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,ANCHOR_TOP);

      //--- установим цвет знака

      ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);

      //--- установим стиль окаймляющей линии

      ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,STYLE_SOLID);

      //--- установим размер знака

      ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,10);

      //--- отобразим на переднем (false) или заднем (true) плане

      ObjectSetInteger(chart_ID,name,OBJPROP_BACK,false);

      //--- включим (true) или отключим (false) режим перемещения знака мышью

      //--- при создании графического объекта функцией ObjectCreate, по умолчанию объект

      //--- нельзя выделить и перемещать. Внутри же этого метода параметр selection

      //--- по умолчанию равен true, что позволяет выделять и перемещать этот объект

      ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,true);

      ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,false);

      //--- скроем (true) или отобразим (false) имя графического объекта в списке объектов

      ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,false);

      //--- установим приоритет на получение события нажатия мыши на графике

      ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,2);

     }
  }
//+------------------------------------------------------------------+
//|               create_text_  (по координатам)                     |
//+------------------------------------------------------------------+
bool create_text_(string name,string text,datetime time,double price,color clr)

  {

// ChangeTextEmptyPoint(time,price);

   error=ObjectCreate(chart_ID,name,OBJ_TEXT,0,time,price);

//--- установим текст

   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text);

//--- установим шрифт текста

   ObjectSetString(chart_ID,name,OBJPROP_FONT,"Calibri");

//--- установим размер шрифта

   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,font_size_text_);

//--- установим угол наклона текста

   ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,0);

//--- установим способ привязки

   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,ANCHOR_CENTER);

//--- установим цвет

   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);

//--- отобразим на переднем (false) или заднем (true) плане

   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,false);

//--- включим (true) или отключим (false) режим перемещения объекта мышью

   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,true);

   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,false);

//--- скроем (true) или отобразим (false) имя графического объекта в списке объектов

   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,false);

//--- установим приоритет на получение события нажатия мыши на графике

   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,0);

   return(true);

  }



//+------------------------------------------------------------------+
