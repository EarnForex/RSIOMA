//+------------------------------------------------------------------+
//|                                                       RSIOMA.mq4 |
//|                             Copyright © 2004-2022, EarnForex.com |
//|                                        https://www.earnforex.com |
//|       Based on indicator by Kalenzo (bartlomiej.gorski@gmail.com |
//|                                         http://www.fxservice.eu) |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2004-2022, EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-indicators/RSIOMA/"
#property version   "1.01"
#property strict

#property description "RSIOMA displays a Relative Strenfth Index built based on relative MA strength, instead of the normal Close values."
#property description "The thin line is the MA of RSIOMA."
#property description "Main signal: RSIOMA crosses 20 from below or 80 from above."
#property description "Auxiliary signal: RSIOMA starts rising below 20 or starts falling above 80."

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_color1 clrBlue
#property indicator_type1  DRAW_LINE
#property indicator_width1 3
#property indicator_label1 "RSIOMA"
#property indicator_color2 clrRed
#property indicator_type2  DRAW_HISTOGRAM
#property indicator_label2 "Trend Down"
#property indicator_color3 clrGreen
#property indicator_type3  DRAW_HISTOGRAM
#property indicator_label3 "Trend Up"
#property indicator_color4 clrMagenta
#property indicator_type4  DRAW_HISTOGRAM
#property indicator_label4 "Reversal from Above"
#property indicator_color5 clrDodgerBlue
#property indicator_type5  DRAW_HISTOGRAM
#property indicator_label5 "Reversal from Below"
#property indicator_color6 clrBlueViolet
#property indicator_type6  DRAW_LINE
#property indicator_label6 "MA of RSIOMA"

#property indicator_minimum -10
#property indicator_maximum 100

enum enum_candle_to_check
{
    Current,
    Previous
};

input int                  RSIOMA              = 14; // RSIOMA Period
input ENUM_MA_METHOD       RSIOMA_MODE         = MODE_EMA; // RSIOMA Mode
input ENUM_APPLIED_PRICE   RSIOMA_PRICE        = PRICE_CLOSE; // RSIOMA Price
input int                  Ma_RSIOMA           = 21; // MA of RSIOMA Period
input ENUM_MA_METHOD       Ma_RSIOMA_MODE      = MODE_EMA; // MA of RSIOMA Mode
input int                  BuyTrigger          = 20;
input int                  SellTrigger         = 80;
input color                BuyTriggerColor     = clrMagenta;
input color                SellTriggerColor    = clrDodgerBlue;
input int                  MainTrendLong       = 50;
input int                  MainTrendShort      = 50;
input color                MainTrendLongColor  = clrRed;
input color                MainTrendShortColor = clrGreen;
input bool                 MainAlerts          = false;
input bool                 AuxiliaryAlerts     = false;
input bool                 EnableNativeAlerts  = false;
input bool                 EnableEmailAlerts   = false;
input bool                 EnablePushAlerts    = false;
input enum_candle_to_check TriggerCandle       = Previous;

// Indicator buffers:
double RSIBuffer[];
double PosBuffer[];
double NegBuffer[];
double bdn[], bup[];
double sdn[], sup[];
double marsioma[];

// Global variables:
string short_name;
datetime LastAlertTime = D'01.01.1970';

void OnInit()
{
    SetIndexBuffer(0, RSIBuffer);
    SetIndexBuffer(1, bdn);
    SetIndexBuffer(2, bup);
    SetIndexBuffer(3, sdn);
    SetIndexBuffer(4, sup);
    SetIndexBuffer(5, marsioma);
    SetIndexBuffer(6, PosBuffer);
    SetIndexBuffer(7, NegBuffer);

    SetIndexDrawBegin(0, RSIOMA);
    SetIndexDrawBegin(1, RSIOMA);
    SetIndexDrawBegin(2, RSIOMA);
    SetIndexDrawBegin(3, RSIOMA);
    SetIndexDrawBegin(4, RSIOMA);
    SetIndexDrawBegin(5, RSIOMA);

    short_name = StringConcatenate("RSIOMA(", RSIOMA, ")");
    IndicatorShortName(short_name);
    IndicatorSetInteger(INDICATOR_DIGITS, 2);

    drawLine(MainTrendLong, "MainTrendLong", MainTrendLongColor);
    drawLine(MainTrendShort, "MainTrendShort", MainTrendShortColor);
    drawLine(BuyTrigger, "BuyTrigger", BuyTriggerColor);
    drawLine(SellTrigger, "SellTrigger", SellTriggerColor );
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    int    i, counted_bars = IndicatorCounted();
    if (Bars <= RSIOMA) return 0;
    if (counted_bars < 1)
        for (i = 1; i <= RSIOMA; i++) RSIBuffer[Bars - i] = 0.0;

    i = Bars - RSIOMA - 1;
    int ma = i;
    if (counted_bars >= RSIOMA) i = Bars - counted_bars;
    while (i >= 0)
    {
        double sumn = 0.0, sump = 0.0;
        double rel, negative, positive;
        if (i == Bars - RSIOMA - 1)
        {
            int k = Bars - 2;
            // Initial accumulation.
            while (k >= i)
            {

                double cma = iMA(Symbol(), 0, RSIOMA, 0, RSIOMA_MODE, RSIOMA_PRICE, k);
                double pma = iMA(Symbol(), 0, RSIOMA, 0, RSIOMA_MODE, RSIOMA_PRICE, k + 1);

                rel = cma - pma;

                if (rel > 0) sump += rel;
                else         sumn -= rel;
                k--;
            }
            positive = sump / RSIOMA;
            negative = sumn / RSIOMA;
        }
        else
        {
            // Smoothed moving average.
            double ccma = iMA(Symbol(), 0, RSIOMA, 0, RSIOMA_MODE, RSIOMA_PRICE, i);
            double ppma = iMA(Symbol(), 0, RSIOMA, 0, RSIOMA_MODE, RSIOMA_PRICE, i + 1);

            rel = ccma - ppma;

            if (rel > 0) sump = rel;
            else         sumn = -rel;
            positive = (PosBuffer[i + 1] * (RSIOMA - 1) + sump) / RSIOMA;
            negative = (NegBuffer[i + 1] * (RSIOMA - 1) + sumn) / RSIOMA;
        }
        PosBuffer[i] = positive;
        NegBuffer[i] = negative;
        if (negative == 0.0) RSIBuffer[i] = 0.0;
        else
        {
            RSIBuffer[i] = 100.0 - 100.0 / (1 + positive / negative);

            if (RSIBuffer[i] > MainTrendLong)
            {
                bup[i] = -10;
                bdn[i] = 0;
                sdn[i] = 0;
                sup[i] = 0;
            }
            if (RSIBuffer[i] < MainTrendShort)
            {
                bdn[i] = -10;
                bup[i] = 0;
                sdn[i] = 0;
                sup[i] = 0;
            }
            if ((RSIBuffer[i] < BuyTrigger) && (RSIBuffer[i] > RSIBuffer[i + 1]))
            {
                sup[i] = -10;
                bdn[i] = 0;
                bup[i] = 0;
                sdn[i] = 0;
            }
            if ((RSIBuffer[i] > SellTrigger) && (RSIBuffer[i] < RSIBuffer[i + 1]))
            {
                sdn[i] = -10;
                bdn[i] = 0;
                bup[i] = 0;
                sup[i] = 0;
            }
        }
        i--;
    }

    while (ma >= 0)
    {
        marsioma[ma] = iMAOnArray(RSIBuffer, 0, Ma_RSIOMA, 0, Ma_RSIOMA_MODE, ma);
        ma--;
    }

    // Alerts
    if (((TriggerCandle > 0) && (Time[0] > LastAlertTime)) || (TriggerCandle == 0))
    {
        string Text;
        if (MainAlerts) // RSIOMA line crosses 80 or 20 lines from above or below.
        {
            // Main Sell signal.
            if ((RSIBuffer[TriggerCandle] < SellTrigger) && (RSIBuffer[TriggerCandle + 1] >= SellTrigger))
            {
                Text = "RSIOMA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Crossed " + IntegerToString(SellTrigger) + " from above.";
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("RSIOMA Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                LastAlertTime = Time[0];
            }
            // Main Buy signal.
            if ((RSIBuffer[TriggerCandle] > BuyTrigger) && (RSIBuffer[TriggerCandle + 1] <= BuyTrigger))
            {
                Text = "RSIOMA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Crossed " + IntegerToString(BuyTrigger) + " from below.";
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("RSIOMA Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                LastAlertTime = Time[0];
            }
        }
        if (AuxiliaryAlerts) // Histogram shows blue or pink color - reversal of RSIOMA below 20 or above 80 - trend change imminent.
        {
            // Auxiliary Sell signal.
            if ((sdn[TriggerCandle] == -10) && (sdn[TriggerCandle + 1] == 0))
            {
                Text = "RSIOMA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Bearish reversal imminent.";
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("RSIOMA Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                LastAlertTime = Time[0];
            }
            // Auxiliary Buy signal.
            if ((sup[TriggerCandle] == -10) && (sup[TriggerCandle + 1] == 0))
            {
                Text = "RSIOMA: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Bullish reversal imminent.";
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("RSIOMA Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                LastAlertTime = Time[0];
            }
        }
    }

    return rates_total;
}

void drawLine(const double lvl, const string name, const color Col)
{
    ObjectDelete(name);
    ObjectCreate(name, OBJ_HLINE, WindowFind(short_name), Time[0], lvl, Time[0], lvl);
    ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSet(name, OBJPROP_COLOR, Col);
    ObjectSet(name, OBJPROP_WIDTH, 1);
    ObjectSet(name, OBJPROP_SELECTABLE, false);
}
//+------------------------------------------------------------------+