//+------------------------------------------------------------------+
//| Gold_Trend_State.mq5                                             |
//| XAUUSD M1 market state: STRONG UP / STRONG DOWN / SIDEWAYS        |
//| Confirmed on M5 + M15, spread filter, alerts on every change      |
//+------------------------------------------------------------------+
#property copyright   "batool-teamnak"
#property version     "1.00"
#property description "3 market states for XAUUSD M1: strong up, strong down, sideways."
#property description "Confirmed on M5/M15 (EMA trend, ADX strength, swing structure)."
#property description "Spread filter and popup / sound / push alerts on every state change."
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1
#property indicator_minimum -1.2
#property indicator_maximum 1.2
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLimeGreen,clrRed,clrDimGray,clrOrange
#property indicator_width1  3
#property indicator_label1  "State"

input group "Confirmation timeframes"
input ENUM_TIMEFRAMES InpTfFast        = PERIOD_M5;   // Fast confirmation TF
input ENUM_TIMEFRAMES InpTfSlow        = PERIOD_M15;  // Slow confirmation TF
input group "Trend"
input int             InpEmaFast       = 21;          // EMA fast
input int             InpEmaSlow       = 50;          // EMA slow
input int             InpAdxPeriod     = 14;          // ADX period (fast TF)
input double          InpAdxMin        = 25.0;        // ADX minimum for "strong"
input bool            InpUseStructure  = true;        // Require HH/HL or LH/LL on fast TF
input int             InpSwingStrength = 3;           // Swing pivot strength (bars each side)
input int             InpConfirmBars   = 3;           // M1 bars a new state must hold
input group "Spread filter"
input bool            InpUseSpread     = true;        // No signals while spread is too high
input double          InpMaxSpreadPips = 0.9;         // Max spread (pips)
input int             InpPointsPerPip  = 10;          // Points per pip (gold 2 digits: 10 -> 0.9 pip = 0.09)
input group "Alerts"
input bool            InpAlertPopup    = true;        // Popup alert
input bool            InpAlertSound    = true;        // Sound alert
input string          InpSoundFile     = "alert.wav"; // Sound file
input bool            InpAlertPush     = true;        // Mobile push notification
input group "Display"
input int             InpMaxBars       = 5000;        // History bars to calculate
input bool            InpShowLabel     = true;        // Show state label

double StateBuf[], ColorBuf[], TrendBuf[], RawBuf[];

struct TfData
{
   ENUM_TIMEFRAMES tf;
   int    hEmaF, hEmaS, hAdx, n;
   double c[], h[], l[], ef[], es[], adx[], pdi[], mdi[];
};
TfData Fast, Slow;

int    lastAlerted = 99;
string labelName   = "GTS_Label";

//+------------------------------------------------------------------+
bool InitTf(TfData &d, ENUM_TIMEFRAMES tf, bool withAdx)
{
   d.tf    = tf;
   d.hEmaF = iMA(_Symbol, tf, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   d.hEmaS = iMA(_Symbol, tf, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   d.hAdx  = withAdx ? iADX(_Symbol, tf, InpAdxPeriod) : INVALID_HANDLE;
   d.n     = 0;
   return d.hEmaF != INVALID_HANDLE && d.hEmaS != INVALID_HANDLE && (!withAdx || d.hAdx != INVALID_HANDLE);
}

bool LoadTf(TfData &d, int need)
{
   int n = MathMin(Bars(_Symbol, d.tf), need);
   if(n < InpEmaSlow + 10) return false;
   ArraySetAsSeries(d.c, true);  ArraySetAsSeries(d.h, true);  ArraySetAsSeries(d.l, true);
   ArraySetAsSeries(d.ef, true); ArraySetAsSeries(d.es, true);
   if(CopyClose(_Symbol, d.tf, 0, n, d.c) < n) return false;
   if(CopyHigh(_Symbol, d.tf, 0, n, d.h) < n)  return false;
   if(CopyLow(_Symbol, d.tf, 0, n, d.l) < n)   return false;
   if(CopyBuffer(d.hEmaF, 0, 0, n, d.ef) < n)  return false;
   if(CopyBuffer(d.hEmaS, 0, 0, n, d.es) < n)  return false;
   if(d.hAdx != INVALID_HANDLE)
   {
      ArraySetAsSeries(d.adx, true); ArraySetAsSeries(d.pdi, true); ArraySetAsSeries(d.mdi, true);
      if(CopyBuffer(d.hAdx, 0, 0, n, d.adx) < n) return false;
      if(CopyBuffer(d.hAdx, 1, 0, n, d.pdi) < n) return false;
      if(CopyBuffer(d.hAdx, 2, 0, n, d.mdi) < n) return false;
   }
   d.n = n;
   return true;
}

// Two most recent confirmed swing points at or before closed bar k (series index)
bool Swings(const double &a[], bool high, int k, int n, double &v1, double &v2)
{
   int S = InpSwingStrength, found = 0;
   for(int j = k + S; j < n - S && j < k + 400; j++)
   {
      bool ok = true;
      for(int m = 1; m <= S && ok; m++)
      {
         if(high) ok = a[j - m] < a[j] && a[j + m] <= a[j];
         else     ok = a[j - m] > a[j] && a[j + m] >= a[j];
      }
      if(!ok) continue;
      if(found == 0) v1 = a[j];
      else { v2 = a[j]; return true; }
      found++;
   }
   return false;
}

int Structure(TfData &d, int k)
{
   double h1, h2, l1, l2;
   if(!Swings(d.h, true, k, d.n, h1, h2) || !Swings(d.l, false, k, d.n, l1, l2)) return 0;
   if(l1 > l2 && (h1 > h2 || d.c[k] > h1)) return 1;
   if(h1 < h2 && (l1 < l2 || d.c[k] < l1)) return -1;
   return 0;
}

int EmaDir(TfData &d, int k)
{
   if(d.ef[k] > d.es[k] && d.c[k] > d.ef[k]) return 1;
   if(d.ef[k] < d.es[k] && d.c[k] < d.ef[k]) return -1;
   return 0;
}

// Raw state for an M1 bar opened at t, using only closed HTF bars
int RawState(datetime t)
{
   int kf = iBarShift(_Symbol, Fast.tf, t, false) + 1;
   int ks = iBarShift(_Symbol, Slow.tf, t, false) + 1;
   if(kf < 1 || ks < 1 || kf + InpSwingStrength + 2 >= Fast.n || ks >= Slow.n) return 0;

   int dir = EmaDir(Fast, kf);
   if(dir == 0 || EmaDir(Slow, ks) != dir) return 0;
   if(Fast.adx[kf] < InpAdxMin) return 0;
   if(dir > 0 ? Fast.pdi[kf] <= Fast.mdi[kf] : Fast.mdi[kf] <= Fast.pdi[kf]) return 0;
   if(InpUseStructure && Structure(Fast, kf) != dir) return 0;
   return dir;
}

string StateText(int s)
{
   return s > 0 ? "STRONG UP" : s < 0 ? "STRONG DOWN" : "SIDEWAYS";
}

double MaxSpreadPoints() { return InpMaxSpreadPips * InpPointsPerPip; }

bool SpreadOk()
{
   return !InpUseSpread || SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= MaxSpreadPoints();
}

void UpdateLabel(int state)
{
   if(!InpShowLabel) return;
   int win = ChartWindowFind();
   if(win < 0) return;
   if(ObjectFind(0, labelName) < 0)
   {
      ObjectCreate(0, labelName, OBJ_LABEL, win, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 4);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
   long   sp  = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool   ok  = SpreadOk();
   string txt = StateText(state) + "   spread " + DoubleToString(sp / (double)InpPointsPerPip, 1) + " pip"
                + (ok ? "" : "  > " + DoubleToString(InpMaxSpreadPips, 1) + "  NO SIGNALS");
   color  clr = !ok ? clrOrange : state > 0 ? clrLimeGreen : state < 0 ? clrRed : clrSilver;
   ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
}

void SendAlerts(int state)
{
   string msg = _Symbol + " " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7) + ": " + StateText(state)
                + (state == 0 ? " (no dominant side)" : state > 0 ? " (buyers dominant)" : " (sellers dominant)");
   if(InpAlertPopup) Alert(msg);
   if(InpAlertSound) PlaySound(InpSoundFile);
   if(InpAlertPush)  SendNotification(msg);
}

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, StateBuf, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuf, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, TrendBuf, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, RawBuf,   INDICATOR_CALCULATIONS);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME, "Gold Trend State");
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

   if(PeriodSeconds(InpTfFast) <= PeriodSeconds() || PeriodSeconds(InpTfSlow) < PeriodSeconds(InpTfFast))
   {
      Print("Confirmation timeframes must be higher than the chart timeframe (use an M1 chart).");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!InitTf(Fast, InpTfFast, true) || !InitTf(Slow, InpTfSlow, false))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, labelName);
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
   // State only changes when a new M1 bar opens; between bars just refresh the label
   if(prev_calculated == rates_total && prev_calculated > 0)
   {
      UpdateLabel((int)TrendBuf[rates_total - 1]);
      return rates_total;
   }

   int span = MathMin(InpMaxBars, rates_total - 1);
   int needF = (int)((long)span * PeriodSeconds() / PeriodSeconds(InpTfFast)) + 500;
   int needS = (int)((long)span * PeriodSeconds() / PeriodSeconds(InpTfSlow)) + 200;
   if(!LoadTf(Fast, needF) || !LoadTf(Slow, needS)) return 0;

   int begin = rates_total - span;
   int start = prev_calculated > 0 ? prev_calculated - 1 : begin;
   if(prev_calculated == 0)
      for(int i = 0; i < begin; i++)
      {
         StateBuf[i] = EMPTY_VALUE; ColorBuf[i] = 2; TrendBuf[i] = 0; RawBuf[i] = 0;
      }

   double maxPts = MaxSpreadPoints();
   for(int i = start; i < rates_total; i++)
   {
      RawBuf[i] = RawState(time[i]);

      // Sticky state: switch only after the new raw state holds for InpConfirmBars bars
      int prev = i > begin ? (int)TrendBuf[i - 1] : (int)RawBuf[i];
      int cur  = prev;
      if((int)RawBuf[i] != prev)
      {
         bool hold = i - InpConfirmBars + 1 >= begin;
         for(int m = 1; m < InpConfirmBars && hold; m++)
            hold = RawBuf[i - m] == RawBuf[i];
         if(hold) cur = (int)RawBuf[i];
      }
      TrendBuf[i] = cur;

      bool spreadHigh = InpUseSpread && i < rates_total - 1 && spread[i] > maxPts;
      StateBuf[i] = spreadHigh || cur == 0 ? 0.3 : cur;
      ColorBuf[i] = spreadHigh ? 3 : cur > 0 ? 0 : cur < 0 ? 1 : 2;
   }

   // Alert on the last closed bar's state when it differs from what was last alerted
   int closed = (int)TrendBuf[rates_total - 2];
   if(prev_calculated == 0 || lastAlerted == 99)
      lastAlerted = closed;
   else if(closed != lastAlerted && SpreadOk())
   {
      SendAlerts(closed);
      lastAlerted = closed;
   }

   UpdateLabel((int)TrendBuf[rates_total - 1]);
   return rates_total;
}
//+------------------------------------------------------------------+
