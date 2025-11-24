// -------------------------------------------------------------------------------
//   RSIOMA displays a Relative Strength Index built based on relative MA strength, instead of the normal Close values.
//   The thin line is the MA of RSIOMA.
//   Main signal: RSIOMA crosses 20 from below or 80 from above.
//   Auxiliary signal: RSIOMA starts rising below 20 or starts falling above 80.
//   
//   Based on indicator by Kalenzo (bartlomiej.gorski@gmail.com http://www.fxservice.eu)
//
//   Version 1.02
//   Copyright 2025, EarnForex.com
//   https://www.earnforex.com/indicators/RSIOMA/
// -------------------------------------------------------------------------------

using System;
using cAlgo.API;
using cAlgo.API.Indicators;

namespace cAlgo.Indicators
{
    [Indicator(IsOverlay = false, AccessRights = AccessRights.None)]
    public class RSIOMA : Indicator
    {
        [Parameter("RSIOMA Period", DefaultValue = 14, MinValue = 1)]
        public int RSIOMAPeriod { get; set; }

        [Parameter("RSIOMA Mode", DefaultValue = MovingAverageType.Exponential)]
        public MovingAverageType RSIOMAMode { get; set; }

        [Parameter("MA of RSIOMA Period", DefaultValue = 21, MinValue = 1)]
        public int MaRSIOMAPeriod { get; set; }

        [Parameter("MA of RSIOMA Mode", DefaultValue = MovingAverageType.Exponential)]
        public MovingAverageType MaRSIOMAMode { get; set; }

        [Parameter("Buy Trigger", DefaultValue = 20)]
        public int BuyTrigger { get; set; }

        [Parameter("Sell Trigger", DefaultValue = 80)]
        public int SellTrigger { get; set; }

        [Parameter("Buy Trigger Color", DefaultValue = "Magenta")]
        public string BuyTriggerColorStr { get; set; }

        [Parameter("Sell Trigger Color", DefaultValue = "DodgerBlue")]
        public string SellTriggerColorStr { get; set; }

        [Parameter("Main Trend Long", DefaultValue = 50)]
        public int MainTrendLong { get; set; }

        [Parameter("Main Trend Short", DefaultValue = 50)]
        public int MainTrendShort { get; set; }

        [Parameter("Main Trend Long Color", DefaultValue = "Red")]
        public string MainTrendLongColorStr { get; set; }

        [Parameter("Main Trend Short Color", DefaultValue = "Green")]
        public string MainTrendShortColorStr { get; set; }

        [Parameter("Main Alerts", DefaultValue = false)]
        public bool MainAlerts { get; set; }

        [Parameter("Auxiliary Alerts", DefaultValue = false)]
        public bool AuxiliaryAlerts { get; set; }

        [Parameter("Enable Native Alerts", DefaultValue = false)]
        public bool EnableNativeAlerts { get; set; }

        [Parameter("Enable Email Alerts", DefaultValue = false)]
        public bool EnableEmailAlerts { get; set; }

        [Parameter("Email Address", DefaultValue = "", Group = "Alerts")]
        public string EmailAddress { get; set; }

        [Parameter("Enable Sound Alerts", DefaultValue = false)]
        public bool EnableSoundAlerts { get; set; }

        [Parameter("Sound Type", DefaultValue = SoundType.Announcement, Group = "Alerts")]
        public SoundType SoundType { get; set; }

        [Parameter("Trigger Candle", DefaultValue = 1)]
        public int TriggerCandle { get; set; }

        [Output("RSIOMA", LineColor = "Blue", LineStyle = LineStyle.Solid, Thickness = 3)]
        public IndicatorDataSeries RSIBuffer { get; set; }

        [Output("Trend Down", LineColor = "Red", PlotType = PlotType.Histogram)]
        public IndicatorDataSeries TrendDown { get; set; }

        [Output("Trend Up", LineColor = "Green", PlotType = PlotType.Histogram)]
        public IndicatorDataSeries TrendUp { get; set; }

        [Output("Reversal from Above", LineColor = "Magenta", PlotType = PlotType.Histogram)]
        public IndicatorDataSeries ReversalFromAbove { get; set; }

        [Output("Reversal from Below", LineColor = "DodgerBlue", PlotType = PlotType.Histogram)]
        public IndicatorDataSeries ReversalFromBelow { get; set; }

        [Output("MA of RSIOMA", LineColor = "BlueViolet", LineStyle = LineStyle.Solid)]
        public IndicatorDataSeries MaRSIOMA { get; set; }

        private IndicatorDataSeries PosBuffer;
        private IndicatorDataSeries NegBuffer;
        private MovingAverage ma;
        private MovingAverage maOfRSIOMA;
        private DateTime lastAlertTime = DateTime.MinValue;

        protected override void Initialize()
        {
            PosBuffer = CreateDataSeries();
            NegBuffer = CreateDataSeries();
            
            // Initialize the moving average for price
            ma = Indicators.MovingAverage(Bars.ClosePrices, RSIOMAPeriod, RSIOMAMode);
            
            // Initialize the moving average for RSIOMA
            maOfRSIOMA = Indicators.MovingAverage(RSIBuffer, MaRSIOMAPeriod, MaRSIOMAMode);
            
            // Draw horizontal lines in the indicator area
            DrawHorizontalLine("MainTrendLong", MainTrendLong, MainTrendLongColorStr);
            DrawHorizontalLine("MainTrendShort", MainTrendShort, MainTrendShortColorStr);
            DrawHorizontalLine("BuyTrigger", BuyTrigger, BuyTriggerColorStr);
            DrawHorizontalLine("SellTrigger", SellTrigger, SellTriggerColorStr);
        }

        public override void Calculate(int index)
        {
            if (index < RSIOMAPeriod * 2) // Avoid using MA values before they can be calculated.
                return;

            double sumn = 0.0, sump = 0.0;
            double rel, negative, positive;

            if (index == RSIOMAPeriod * 2)
            {
                // Initial accumulation
                for (int k = 1; k <= RSIOMAPeriod; k++)
                {
                    rel = ma.Result[index - k + 1] - ma.Result[index - k];
                    
                    if (rel > 0) 
                        sump += rel;
                    else 
                        sumn -= rel;
                }
                positive = sump / RSIOMAPeriod;
                negative = sumn / RSIOMAPeriod;
            }
            else
            {
                // Smoothed moving average
                rel = ma.Result[index] - ma.Result[index - 1];
                
                if (rel > 0) 
                    sump = rel;
                else 
                    sumn = -rel;
                    
                positive = (PosBuffer[index - 1] * (RSIOMAPeriod - 1) + sump) / RSIOMAPeriod;
                negative = (NegBuffer[index - 1] * (RSIOMAPeriod - 1) + sumn) / RSIOMAPeriod;
            }

            PosBuffer[index] = positive;
            NegBuffer[index] = negative;

            if (negative == 0.0)
                RSIBuffer[index] = 0.0;
            else
            {
                RSIBuffer[index] = 100.0 - 100.0 / (1 + positive / negative);

                // Reset all histogram values
                TrendDown[index] = double.NaN;
                TrendUp[index] = double.NaN;
                ReversalFromAbove[index] = double.NaN;
                ReversalFromBelow[index] = double.NaN;

                // Set histogram values based on conditions
                if (RSIBuffer[index] > MainTrendLong)
                {
                    TrendUp[index] = -10;
                }
                else if (RSIBuffer[index] < MainTrendShort)
                {
                    TrendDown[index] = -10;
                }
                else if (index > 0)
                {
                    if ((RSIBuffer[index] < BuyTrigger) && (RSIBuffer[index] > RSIBuffer[index - 1]))
                    {
                        ReversalFromBelow[index] = -10;
                    }
                    else if ((RSIBuffer[index] > SellTrigger) && (RSIBuffer[index] < RSIBuffer[index - 1]))
                    {
                        ReversalFromAbove[index] = -10;
                    }
                }
            }

            // Calculate MA of RSIOMA - the MovingAverage indicator handles this automatically
            if (index >= RSIOMAPeriod * 2 + MaRSIOMAPeriod - 1)
            {
                MaRSIOMA[index] = maOfRSIOMA.Result[index];
            }

            // Alerts
            CheckAlerts(index);
        }

        private void CheckAlerts(int index)
        {
            if (index != Bars.Count - 1 - TriggerCandle)
                return;

            if ((TriggerCandle > 0 && Bars.OpenTimes[index] > lastAlertTime) || TriggerCandle == 0)
            {
                string text = "";
                
                if (MainAlerts && index > 0)
                {
                    // Main Sell signal
                    if ((RSIBuffer[index] < SellTrigger) && (RSIBuffer[index - 1] >= SellTrigger))
                    {
                        text = "RSIOMA: " + Symbol.Name + " - " + TimeFrame.ToString() + " - Crossed " + SellTrigger + " from above.";
                        IssueAlerts(text);
                    }
                    // Main Buy signal
                    else if ((RSIBuffer[index] > BuyTrigger) && (RSIBuffer[index - 1] <= BuyTrigger))
                    {
                        text = "RSIOMA: " + Symbol.Name + " - " + TimeFrame.ToString() + " - Crossed " + BuyTrigger + " from below.";
                        IssueAlerts(text);
                    }
                }
                
                if (AuxiliaryAlerts && index > 0)
                {
                    // Auxiliary Sell signal
                    if (!double.IsNaN(ReversalFromAbove[index]) && double.IsNaN(ReversalFromAbove[index - 1]))
                    {
                        text = "RSIOMA: " + Symbol.Name + " - " + TimeFrame.ToString() + " - Bearish reversal imminent.";
                        IssueAlerts(text);
                    }
                    // Auxiliary Buy signal
                    else if (!double.IsNaN(ReversalFromBelow[index]) && double.IsNaN(ReversalFromBelow[index - 1]))
                    {
                        text = "RSIOMA: " + Symbol.Name + " - " + TimeFrame.ToString() + " - Bullish reversal imminent.";
                        IssueAlerts(text);
                    }
                }
            }
        }

        private void IssueAlerts(string text)
        {
            if (EnableNativeAlerts)
            {
                Notifications.ShowPopup("RSIOMA Alert", text, PopupNotificationState.Information);
                Print(text);
            }

            if (EnableEmailAlerts)
            {
                string subject = $"RSIOMA {Symbol.Name} Notification ({TimeFrame.ToString()})";
                string body = $"{Account.BrokerName} - {Account.Number}\n" +
                             $"RSIOMA Notification for {Symbol.Name} @ {TimeFrame.ToString()}\n" +
                             $"{text}";
                Notifications.SendEmail(EmailAddress, EmailAddress, subject, body);
            }

            if (EnableSoundAlerts)
            {
                Notifications.PlaySound(SoundType);
            }
            
            lastAlertTime = Bars.OpenTimes[Bars.Count - 1 - TriggerCandle];
        }

        private void DrawHorizontalLine(string name, double level, string colorStr)
        {
            Color lineColor = Color.FromName(colorStr);
            IndicatorArea.DrawHorizontalLine(name, level, lineColor, 1, LineStyle.Dots);
        }
    }
}
//+------------------------------------------------------------------+