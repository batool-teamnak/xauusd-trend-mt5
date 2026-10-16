//+------------------------------------------------------------------+
//| GTS_Probe.mq5 — strategy tester harness for Gold_Trend_State     |
//| 1) Logs how the states behave (time share, flips, forward moves) |
//| 2) Runs a proxy one-direction scalper with and without the filter|
//+------------------------------------------------------------------+
#property copyright "batool-teamnak"
#property version   "1.00"
#include <Trade/Trade.mqh>

input int    InpMode          = 1;     // 0 = scalper always on, 1 = only with dominant state, 2 = no trades (stats only)
input double InpLots          = 1.0;
input double InpTP            = 0.25;  // Proxy take profit (price)
input double InpSL            = 0.40;  // Proxy stop loss (price)
input int    InpDirEma        = 20;    // Proxy scalper direction EMA (M1)
input int    InpEmaFast       = 21;
input int    InpEmaSlow       = 50;
input int    InpAdxPeriod     = 14;
input double InpAdxMin        = 25.0;
input bool   InpUseStructure  = true;
input int    InpSwingStrength = 3;
input int    InpConfirmBars   = 3;

CTrade   trade;
int      hGts, hEma;
datetime lastBar = 0;
int      st[];
double   cl[];
long     sp[];

int OnInit()
{
   // each "input group" in the indicator takes a parameter slot, hence the "" placeholders
   hGts = iCustom(_Symbol, PERIOD_M1, "Gold_Trend_State",
                  "", PERIOD_M5, PERIOD_M15,
                  "", InpEmaFast, InpEmaSlow, InpAdxPeriod, InpAdxMin, InpUseStructure, InpSwingStrength, InpConfirmBars,
                  "", false, 0.9, 10,
                  "", false, false, "alert.wav", false,
                  "", 5000, false);
   hEma = iMA(_Symbol, PERIOD_M1, InpDirEma, 0, MODE_EMA, PRICE_CLOSE);
   if(hGts == INVALID_HANDLE || hEma == INVALID_HANDLE) return INIT_FAILED;
   trade.SetExpertMagicNumber(7301);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   datetime t = iTime(_Symbol, PERIOD_M1, 0);
   if(t == lastBar) return;

   double s[1], e[2];
   if(CopyBuffer(hGts, 2, 1, 1, s) < 1 || CopyBuffer(hEma, 0, 1, 2, e) < 2) return;
   lastBar = t;

   int    state = (int)s[0];
   double c1    = iClose(_Symbol, PERIOD_M1, 1);
   int n = ArraySize(st);
   ArrayResize(st, n + 1, 100000); ArrayResize(cl, n + 1, 100000); ArrayResize(sp, n + 1, 100000);
   st[n] = state; cl[n] = c1; sp[n] = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   if(InpMode == 2 || PositionSelect(_Symbol)) return;

   // e[1] = last closed bar, e[0] = the bar before
   int dir = (c1 > e[1] && e[1] > e[0]) ? 1 : (c1 < e[1] && e[1] < e[0]) ? -1 : 0;
   if(dir == 0) return;
   if(InpMode == 1 && state != dir) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(dir > 0) trade.Buy(InpLots, _Symbol, ask, ask - InpSL, ask + InpTP);
   else        trade.Sell(InpLots, _Symbol, bid, bid + InpSL, bid - InpTP);
}

void FwdStats(int H)
{
   int    n = ArraySize(st);
   double sumDirT = 0, absT = 0, absS = 0; int nT = 0, nS = 0, agree = 0;
   for(int i = 0; i + H < n; i++)
   {
      double f = cl[i + H] - cl[i];
      if(st[i] != 0) { sumDirT += st[i] * f; absT += MathAbs(f); nT++; if(st[i] * f > 0) agree++; }
      else           { absS += MathAbs(f); nS++; }
   }
   PrintFormat("GTS fwd %d bars: trend bars=%d  avg move in state direction=%.3f  moved with state=%.1f%%  avg |move| trend=%.3f  sideways=%.3f",
               H, nT, nT ? sumDirT / nT : 0, nT ? 100.0 * agree / nT : 0, nT ? absT / nT : 0, nS ? absS / nS : 0);
}

void OnDeinit(const int reason)
{
   int n = ArraySize(st);
   if(n < 100) return;
   int up = 0, dn = 0, flips = 0, runs = 0;
   for(int i = 0; i < n; i++)
   {
      if(st[i] > 0) up++; else if(st[i] < 0) dn++;
      if(i > 0 && st[i] != st[i - 1]) flips++;
   }
   PrintFormat("GTS bars=%d  up=%.1f%%  down=%.1f%%  sideways=%.1f%%  state changes=%d  (%.1f per day, avg state length %.0f min)",
               n, 100.0 * up / n, 100.0 * dn / n, 100.0 * (n - up - dn) / n, flips,
               flips / (n / 1380.0), flips ? (double)n / flips : n);
   FwdStats(5); FwdStats(15); FwdStats(30);

   long s2[]; ArrayCopy(s2, sp); ArraySort(s2);
   int ok = 0; for(int i = 0; i < n; i++) if(sp[i] <= 9) ok++;
   PrintFormat("GTS spread points: median=%d  p90=%d  <=9pts(0.9pip)=%.1f%%", s2[n / 2], s2[(int)(n * 0.9)], 100.0 * ok / n);
}

double OnTester()
{
   double p = TesterStatistics(STAT_PROFIT);
   return p == 0 ? 0.01 : p;
}
