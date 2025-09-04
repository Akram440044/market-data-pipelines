#!/usr/bin/env python3
"""
Market Report Generator
Generates daily market summary reports from processed data.
"""

import os
import sys
import pandas as pd
import numpy as np
import logging
import yaml
from datetime import datetime, timedelta
from pathlib import Path
import argparse
import glob
from jinja2 import Template


class MarketReportGenerator:
    def __init__(self, config_path="config/symbols.yaml"):
        """Initialize the report generator."""
        self.script_dir = Path(__file__).parent.parent
        self.config_path = self.script_dir / config_path
        self.config = self._load_config()
        self._setup_logging()
        
    def _load_config(self):
        """Load configuration from YAML file."""
        try:
            with open(self.config_path, 'r') as file:
                return yaml.safe_load(file)
        except Exception as e:
            print(f"Error loading config: {e}")
            return {}
            
    def _setup_logging(self):
        """Setup logging configuration."""
        log_dir = self.script_dir / "logs"
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"report_generation_{datetime.now().strftime('%Y%m%d')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def load_processed_data(self, symbol=None):
        """Load processed data files."""
        processed_dir = self.script_dir / "data" / "processed"
        
        if not processed_dir.exists():
            self.logger.warning("No processed data directory found")
            return {}
            
        data_dict = {}
        
        if symbol:
            pattern = str(processed_dir / f"{symbol}_processed_*.csv")
        else:
            pattern = str(processed_dir / "*_processed_*.csv")
            
        files = glob.glob(pattern)
        
        for file_path in files:
            filename = Path(file_path).name
            symbol_name = filename.split('_')[0]
            
            try:
                data = pd.read_csv(file_path)
                data['Date'] = pd.to_datetime(data['Date'])
                data_dict[symbol_name] = data
                self.logger.info(f"Loaded processed data for {symbol_name}")
            except Exception as e:
                self.logger.error(f"Error loading {file_path}: {e}")
                
        return data_dict
        
    def generate_market_summary(self, data_dict):
        """Generate overall market summary."""
        summary = {
            'date': datetime.now().strftime('%Y-%m-%d'),
            'total_symbols': len(data_dict),
            'gainers': [],
            'losers': [],
            'high_volume': [],
            'alerts': []
        }
        
        for symbol, data in data_dict.items():
            if data.empty:
                continue
                
            latest = data.iloc[-1]
            
            # Skip if essential data is missing
            if pd.isna(latest['Daily_Return']) or pd.isna(latest['Close']):
                continue
                
            symbol_info = {
                'symbol': symbol,
                'price': latest['Close'],
                'change': latest['Daily_Return'] * 100,
                'volume': latest['Volume'],
                'volume_ratio': latest.get('Volume_Ratio', np.nan)
            }
            
            # Categorize gainers and losers
            if latest['Daily_Return'] > 0.02:  # > 2% gain
                summary['gainers'].append(symbol_info)
            elif latest['Daily_Return'] < -0.02:  # > 2% loss
                summary['losers'].append(symbol_info)
                
            # High volume alerts
            if not pd.isna(symbol_info['volume_ratio']) and symbol_info['volume_ratio'] > self.config.get('alerts', {}).get('volume_multiplier', 2.0):
                summary['high_volume'].append(symbol_info)
                
            # Price change alerts
            price_threshold = self.config.get('alerts', {}).get('price_change_threshold', 5.0) / 100
            if abs(latest['Daily_Return']) > price_threshold:
                alert = {
                    'symbol': symbol,
                    'type': 'price_change',
                    'message': f"{symbol} moved {latest['Daily_Return']*100:.2f}% today",
                    'severity': 'high' if abs(latest['Daily_Return']) > 0.1 else 'medium'
                }
                summary['alerts'].append(alert)
                
        # Sort lists
        summary['gainers'] = sorted(summary['gainers'], key=lambda x: x['change'], reverse=True)[:10]
        summary['losers'] = sorted(summary['losers'], key=lambda x: x['change'])[:10]
        summary['high_volume'] = sorted(summary['high_volume'], key=lambda x: x['volume_ratio'], reverse=True)[:10]
        
        return summary
        
    def generate_symbol_analysis(self, symbol, data):
        """Generate detailed analysis for a single symbol."""
        if data.empty:
            return None
            
        latest = data.iloc[-1]
        prev_day = data.iloc[-2] if len(data) > 1 else latest
        
        # Calculate performance metrics
        returns_30d = data['Daily_Return'].tail(30)
        returns_7d = data['Daily_Return'].tail(7)
        
        analysis = {
            'symbol': symbol,
            'current_price': latest['Close'],
            'daily_change': latest['Daily_Return'] * 100,
            'daily_change_abs': latest['Price_Change'],
            'volume': latest['Volume'],
            'volume_change': ((latest['Volume'] - prev_day['Volume']) / prev_day['Volume'] * 100) if prev_day['Volume'] > 0 else 0,
            
            # Technical indicators
            'rsi': latest.get('RSI', np.nan),
            'sma_20': latest.get('SMA_20', np.nan),
            'sma_50': latest.get('SMA_50', np.nan),
            'bb_position': self._get_bb_position(latest),
            'macd_signal': latest.get('MACD', np.nan),
            
            # Performance metrics
            'volatility': latest.get('Volatility', np.nan),
            'avg_return_7d': returns_7d.mean() * 100,
            'avg_return_30d': returns_30d.mean() * 100,
            'volatility_7d': returns_7d.std() * 100,
            'volatility_30d': returns_30d.std() * 100,
            
            # Trend analysis
            'trend_sma': self._analyze_sma_trend(latest),
            'support_resistance': self._find_support_resistance(data.tail(20))
        }
        
        return analysis
        
    def _get_bb_position(self, row):
        """Get Bollinger Band position description."""
        bb_upper = row.get('BB_Upper', np.nan)
        bb_lower = row.get('BB_Lower', np.nan)
        close = row['Close']
        
        if pd.isna(bb_upper) or pd.isna(bb_lower):
            return "N/A"
            
        if close > bb_upper:
            return "Above Upper Band (Overbought)"
        elif close < bb_lower:
            return "Below Lower Band (Oversold)"
        else:
            return "Within Bands (Normal)"
            
    def _analyze_sma_trend(self, row):
        """Analyze SMA trend."""
        sma_20 = row.get('SMA_20', np.nan)
        sma_50 = row.get('SMA_50', np.nan)
        close = row['Close']
        
        if pd.isna(sma_20) or pd.isna(sma_50):
            return "Insufficient data"
            
        if close > sma_20 > sma_50:
            return "Strong Uptrend"
        elif close > sma_20 and sma_20 < sma_50:
            return "Weak Uptrend"
        elif close < sma_20 < sma_50:
            return "Strong Downtrend"
        else:
            return "Weak Downtrend"
            
    def _find_support_resistance(self, data):
        """Find basic support and resistance levels."""
        if len(data) < 10:
            return {"support": np.nan, "resistance": np.nan}
            
        highs = data['High']
        lows = data['Low']
        
        resistance = highs.quantile(0.9)
        support = lows.quantile(0.1)
        
        return {"support": support, "resistance": resistance}
        
    def create_html_report(self, summary, detailed_analysis):
        """Create HTML report."""
        html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>Daily Market Report - {{ summary.date }}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .card { background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007bff; }
        .card h3 { margin-top: 0; color: #333; }
        .gainers { border-left-color: #28a745; }
        .losers { border-left-color: #dc3545; }
        .volume { border-left-color: #ffc107; }
        .alerts { border-left-color: #fd7e14; }
        .symbol-list { list-style: none; padding: 0; }
        .symbol-list li { padding: 5px 0; border-bottom: 1px solid #eee; }
        .symbol-list li:last-child { border-bottom: none; }
        .positive { color: #28a745; font-weight: bold; }
        .negative { color: #dc3545; font-weight: bold; }
        .detailed { margin-top: 30px; }
        .symbol-detail { margin-bottom: 20px; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; margin-top: 10px; }
        .metric { background: #f1f3f4; padding: 8px; border-radius: 3px; text-align: center; }
        .alert-high { background-color: #f8d7da; border-color: #f5c6cb; color: #721c24; }
        .alert-medium { background-color: #fff3cd; border-color: #ffeaa7; color: #856404; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Daily Market Report</h1>
            <h2>{{ summary.date }}</h2>
            <p>Analyzing {{ summary.total_symbols }} symbols</p>
        </div>
        
        <div class="summary">
            <div class="card gainers">
                <h3>📈 Top Gainers</h3>
                <ul class="symbol-list">
                    {% for stock in summary.gainers[:5] %}
                    <li><strong>{{ stock.symbol }}</strong>: ${{ "%.2f"|format(stock.price) }} <span class="positive">(+{{ "%.2f"|format(stock.change) }}%)</span></li>
                    {% endfor %}
                </ul>
            </div>
            
            <div class="card losers">
                <h3>📉 Top Losers</h3>
                <ul class="symbol-list">
                    {% for stock in summary.losers[:5] %}
                    <li><strong>{{ stock.symbol }}</strong>: ${{ "%.2f"|format(stock.price) }} <span class="negative">({{ "%.2f"|format(stock.change) }}%)</span></li>
                    {% endfor %}
                </ul>
            </div>
            
            <div class="card volume">
                <h3>📊 High Volume</h3>
                <ul class="symbol-list">
                    {% for stock in summary.high_volume[:5] %}
                    <li><strong>{{ stock.symbol }}</strong>: {{ "%.1f"|format(stock.volume_ratio) }}x avg volume</li>
                    {% endfor %}
                </ul>
            </div>
            
            <div class="card alerts">
                <h3>🚨 Alerts</h3>
                <ul class="symbol-list">
                    {% for alert in summary.alerts[:5] %}
                    <li class="alert-{{ alert.severity }}">{{ alert.message }}</li>
                    {% endfor %}
                </ul>
            </div>
        </div>
        
        {% if detailed_analysis %}
        <div class="detailed">
            <h2>Detailed Symbol Analysis</h2>
            {% for analysis in detailed_analysis %}
            <div class="symbol-detail">
                <h3>{{ analysis.symbol }} - ${{ "%.2f"|format(analysis.current_price) }}</h3>
                <div class="metrics">
                    <div class="metric">
                        <strong>Daily Change</strong><br>
                        <span class="{% if analysis.daily_change > 0 %}positive{% else %}negative{% endif %}">{{ "%.2f"|format(analysis.daily_change) }}%</span>
                    </div>
                    <div class="metric">
                        <strong>RSI</strong><br>
                        {{ "%.1f"|format(analysis.rsi) if not analysis.rsi != analysis.rsi else "N/A" }}
                    </div>
                    <div class="metric">
                        <strong>Trend</strong><br>
                        {{ analysis.trend_sma }}
                    </div>
                    <div class="metric">
                        <strong>BB Position</strong><br>
                        {{ analysis.bb_position }}
                    </div>
                    <div class="metric">
                        <strong>30d Volatility</strong><br>
                        {{ "%.2f"|format(analysis.volatility_30d) }}%
                    </div>
                    <div class="metric">
                        <strong>Volume Change</strong><br>
                        <span class="{% if analysis.volume_change > 0 %}positive{% else %}negative{% endif %}">{{ "%.1f"|format(analysis.volume_change) }}%</span>
                    </div>
                </div>
            </div>
            {% endfor %}
        </div>
        {% endif %}
        
        <div style="margin-top: 30px; text-align: center; font-size: 12px; color: #666;">
            Report generated on {{ summary.date }} by Market Data Pipeline
        </div>
    </div>
</body>
</html>
        """
        
        template = Template(html_template)
        return template.render(summary=summary, detailed_analysis=detailed_analysis)
        
    def save_report(self, content, filename):
        """Save report to file."""
        try:
            reports_dir = self.script_dir / "reports"
            reports_dir.mkdir(exist_ok=True)
            
            filepath = reports_dir / filename
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
                
            self.logger.info(f"Report saved to {filepath}")
            return filepath
            
        except Exception as e:
            self.logger.error(f"Error saving report: {e}")
            return None
            
    def generate_daily_report(self, symbols=None):
        """Generate complete daily report."""
        self.logger.info("Starting daily report generation")
        
        # Load data
        data_dict = self.load_processed_data()
        
        if not data_dict:
            self.logger.warning("No processed data found for report generation")
            return None
            
        # Filter symbols if specified
        if symbols:
            data_dict = {k: v for k, v in data_dict.items() if k in symbols}
            
        # Generate summary
        summary = self.generate_market_summary(data_dict)
        
        # Generate detailed analysis for significant movers
        detailed_analysis = []
        significant_symbols = set()
        
        # Add top gainers and losers
        for stock in summary['gainers'][:5] + summary['losers'][:5]:
            significant_symbols.add(stock['symbol'])
            
        # Add high volume stocks
        for stock in summary['high_volume'][:3]:
            significant_symbols.add(stock['symbol'])
            
        for symbol in significant_symbols:
            if symbol in data_dict:
                analysis = self.generate_symbol_analysis(symbol, data_dict[symbol])
                if analysis:
                    detailed_analysis.append(analysis)
                    
        # Create HTML report
        html_content = self.create_html_report(summary, detailed_analysis)
        
        # Save report
        date_str = datetime.now().strftime('%Y%m%d')
        filename = f"market_report_{date_str}.html"
        report_path = self.save_report(html_content, filename)
        
        self.logger.info(f"Daily report generation complete: {len(data_dict)} symbols analyzed")
        
        return report_path


def main():
    parser = argparse.ArgumentParser(description='Generate market reports')
    parser.add_argument('--symbols', nargs='+', help='Specific symbols to include in report')
    parser.add_argument('--config', default='config/symbols.yaml', help='Config file path')
    
    args = parser.parse_args()
    
    generator = MarketReportGenerator(args.config)
    report_path = generator.generate_daily_report(args.symbols)
    
    if report_path:
        print(f"Report generated successfully: {report_path}")
    else:
        print("Failed to generate report")


if __name__ == "__main__":
    main()
