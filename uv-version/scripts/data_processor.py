#!/usr/bin/env python3
"""
Market Data Processor
Processes downloaded market data and calculates technical indicators.
"""

import os
import sys
import pandas as pd
import numpy as np
import logging
from datetime import datetime
from pathlib import Path
import argparse
import glob


class MarketDataProcessor:
    def __init__(self):
        """Initialize the data processor."""
        self.script_dir = Path(__file__).parent.parent
        self._setup_logging()
        
    def _setup_logging(self):
        """Setup logging configuration."""
        log_dir = self.script_dir / "logs"
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"data_processing_{datetime.now().strftime('%Y%m%d')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def calculate_sma(self, data, window=20):
        """Calculate Simple Moving Average."""
        return data['Close'].rolling(window=window).mean()
        
    def calculate_ema(self, data, window=20):
        """Calculate Exponential Moving Average."""
        return data['Close'].ewm(span=window).mean()
        
    def calculate_rsi(self, data, window=14):
        """Calculate Relative Strength Index."""
        delta = data['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=window).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=window).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        return rsi
        
    def calculate_bollinger_bands(self, data, window=20, num_std=2):
        """Calculate Bollinger Bands."""
        sma = self.calculate_sma(data, window)
        std = data['Close'].rolling(window=window).std()
        
        upper_band = sma + (std * num_std)
        lower_band = sma - (std * num_std)
        
        return upper_band, sma, lower_band
        
    def calculate_macd(self, data, fast=12, slow=26, signal=9):
        """Calculate MACD (Moving Average Convergence Divergence)."""
        ema_fast = self.calculate_ema(data, fast)
        ema_slow = self.calculate_ema(data, slow)
        
        macd_line = ema_fast - ema_slow
        signal_line = macd_line.ewm(span=signal).mean()
        histogram = macd_line - signal_line
        
        return macd_line, signal_line, histogram
        
    def calculate_volatility(self, data, window=20):
        """Calculate rolling volatility (standard deviation of returns)."""
        returns = data['Close'].pct_change()
        return returns.rolling(window=window).std() * np.sqrt(252)  # Annualized
        
    def calculate_volume_indicators(self, data):
        """Calculate volume-based indicators."""
        # Volume moving average
        vol_ma = data['Volume'].rolling(window=20).mean()
        
        # Volume ratio (current volume / average volume)
        vol_ratio = data['Volume'] / vol_ma
        
        # On-Balance Volume (OBV)
        obv = np.where(data['Close'] > data['Close'].shift(1), 
                       data['Volume'], 
                       np.where(data['Close'] < data['Close'].shift(1), 
                               -data['Volume'], 0)).cumsum()
        
        return vol_ma, vol_ratio, obv
        
    def process_symbol_data(self, symbol, data_file):
        """Process data for a single symbol and add technical indicators."""
        try:
            self.logger.info(f"Processing data for {symbol}")
            
            # Load data
            data = pd.read_csv(data_file)
            data['Date'] = pd.to_datetime(data['Date'])
            data = data.sort_values('Date').reset_index(drop=True)
            
            # Calculate price-based indicators
            data['SMA_20'] = self.calculate_sma(data, 20)
            data['SMA_50'] = self.calculate_sma(data, 50)
            data['EMA_20'] = self.calculate_ema(data, 20)
            data['RSI'] = self.calculate_rsi(data)
            
            # Bollinger Bands
            bb_upper, bb_middle, bb_lower = self.calculate_bollinger_bands(data)
            data['BB_Upper'] = bb_upper
            data['BB_Middle'] = bb_middle
            data['BB_Lower'] = bb_lower
            
            # MACD
            macd, signal, histogram = self.calculate_macd(data)
            data['MACD'] = macd
            data['MACD_Signal'] = signal
            data['MACD_Histogram'] = histogram
            
            # Volatility
            data['Volatility'] = self.calculate_volatility(data)
            
            # Volume indicators
            vol_ma, vol_ratio, obv = self.calculate_volume_indicators(data)
            data['Volume_MA'] = vol_ma
            data['Volume_Ratio'] = vol_ratio
            data['OBV'] = obv
            
            # Price change indicators
            data['Daily_Return'] = data['Close'].pct_change()
            data['Price_Change'] = data['Close'] - data['Open']
            data['Price_Change_Pct'] = (data['Close'] - data['Open']) / data['Open'] * 100
            
            # High-Low spread
            data['HL_Spread'] = data['High'] - data['Low']
            data['HL_Spread_Pct'] = (data['High'] - data['Low']) / data['Close'] * 100
            
            self.logger.info(f"Added technical indicators for {symbol}")
            return data
            
        except Exception as e:
            self.logger.error(f"Error processing {symbol}: {e}")
            return None
            
    def save_processed_data(self, data, symbol):
        """Save processed data with technical indicators."""
        try:
            processed_dir = self.script_dir / "data" / "processed"
            processed_dir.mkdir(exist_ok=True)
            
            date_str = datetime.now().strftime('%Y%m%d')
            filename = f"{symbol}_processed_{date_str}.csv"
            filepath = processed_dir / filename
            
            data.to_csv(filepath, index=False)
            self.logger.info(f"Saved processed data to {filepath}")
            return filepath
            
        except Exception as e:
            self.logger.error(f"Error saving processed data for {symbol}: {e}")
            return None
            
    def generate_summary_stats(self, data, symbol):
        """Generate summary statistics for the symbol."""
        latest = data.iloc[-1]
        
        summary = {
            'symbol': symbol,
            'date': latest['Date'],
            'close_price': latest['Close'],
            'daily_return': latest['Daily_Return'],
            'volume': latest['Volume'],
            'volume_ratio': latest['Volume_Ratio'],
            'rsi': latest['RSI'],
            'sma_20': latest['SMA_20'],
            'sma_50': latest['SMA_50'],
            'volatility': latest['Volatility'],
            'bb_position': self._calculate_bb_position(latest),
            'macd_signal': self._get_macd_signal(latest)
        }
        
        return summary
        
    def _calculate_bb_position(self, row):
        """Calculate position relative to Bollinger Bands."""
        if pd.isna(row['BB_Upper']) or pd.isna(row['BB_Lower']):
            return 'N/A'
            
        bb_width = row['BB_Upper'] - row['BB_Lower']
        if bb_width == 0:
            return 'N/A'
            
        position = (row['Close'] - row['BB_Lower']) / bb_width
        
        if position > 0.8:
            return 'Upper'
        elif position < 0.2:
            return 'Lower'
        else:
            return 'Middle'
            
    def _get_macd_signal(self, row):
        """Get MACD signal."""
        if pd.isna(row['MACD']) or pd.isna(row['MACD_Signal']):
            return 'N/A'
            
        if row['MACD'] > row['MACD_Signal']:
            return 'Bullish'
        else:
            return 'Bearish'
            
    def process_all_data(self, data_dir=None):
        """Process all available data files."""
        data_dir = data_dir or (self.script_dir / "data")
        
        # Find all CSV files in data directory
        pattern = str(data_dir / "*.csv")
        data_files = glob.glob(pattern)
        
        if not data_files:
            self.logger.warning("No data files found to process")
            return []
            
        summaries = []
        
        for data_file in data_files:
            # Extract symbol from filename
            filename = Path(data_file).name
            if '_' in filename:
                symbol = filename.split('_')[0]
            else:
                symbol = filename.replace('.csv', '')
                
            # Process the data
            processed_data = self.process_symbol_data(symbol, data_file)
            
            if processed_data is not None:
                # Save processed data
                self.save_processed_data(processed_data, symbol)
                
                # Generate summary
                summary = self.generate_summary_stats(processed_data, symbol)
                summaries.append(summary)
                
        return summaries


def main():
    parser = argparse.ArgumentParser(description='Process market data and calculate technical indicators')
    parser.add_argument('--data-dir', help='Directory containing CSV data files')
    parser.add_argument('--symbol', help='Process specific symbol only')
    
    args = parser.parse_args()
    
    processor = MarketDataProcessor()
    
    if args.symbol:
        # Process specific symbol
        data_file = processor.script_dir / "data" / f"{args.symbol}*.csv"
        files = glob.glob(str(data_file))
        if files:
            processed_data = processor.process_symbol_data(args.symbol, files[0])
            if processed_data is not None:
                processor.save_processed_data(processed_data, args.symbol)
        else:
            print(f"No data file found for {args.symbol}")
    else:
        # Process all data
        summaries = processor.process_all_data(args.data_dir)
        print(f"Processed {len(summaries)} symbols")


if __name__ == "__main__":
    main()
