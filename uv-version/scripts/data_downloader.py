#!/usr/bin/env python3
"""
Market Data Downloader
Downloads stock data using yfinance and saves to CSV files.
"""

import os
import sys
import yaml
import yfinance as yf
import pandas as pd
import logging
from datetime import datetime, timedelta
from pathlib import Path
import argparse


class MarketDataDownloader:
    def __init__(self, config_path="config/symbols.yaml"):
        """Initialize the data downloader with configuration."""
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
            sys.exit(1)
            
    def _setup_logging(self):
        """Setup logging configuration."""
        log_dir = self.script_dir / self.config['paths']['logs_dir']
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"data_download_{datetime.now().strftime('%Y%m%d')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def download_symbol_data(self, symbol, period=None, interval=None):
        """Download data for a single symbol."""
        try:
            period = period or self.config['data_settings']['period']
            interval = interval or self.config['data_settings']['interval']
            
            self.logger.info(f"Downloading data for {symbol}")
            
            # Download data using yfinance
            ticker = yf.Ticker(symbol)
            data = ticker.history(period=period, interval=interval)
            
            if data.empty:
                self.logger.warning(f"No data found for {symbol}")
                return None
                
            # Add symbol column
            data['Symbol'] = symbol
            
            # Reset index to make Date a column
            data.reset_index(inplace=True)
            
            self.logger.info(f"Downloaded {len(data)} records for {symbol}")
            return data
            
        except Exception as e:
            self.logger.error(f"Error downloading {symbol}: {e}")
            return None
            
    def save_data(self, data, symbol, date_str=None):
        """Save data to CSV file."""
        if data is None or data.empty:
            return False
            
        try:
            data_dir = self.script_dir / self.config['paths']['data_dir']
            data_dir.mkdir(exist_ok=True)
            
            date_str = date_str or datetime.now().strftime('%Y%m%d')
            filename = f"{symbol}_{date_str}.csv"
            filepath = data_dir / filename
            
            data.to_csv(filepath, index=False)
            self.logger.info(f"Saved data to {filepath}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error saving data for {symbol}: {e}")
            return False
            
    def download_all_symbols(self, symbols=None):
        """Download data for all configured symbols."""
        symbols = symbols or self.config['symbols']
        
        successful_downloads = 0
        failed_downloads = []
        
        self.logger.info(f"Starting download for {len(symbols)} symbols")
        
        for symbol in symbols:
            data = self.download_symbol_data(symbol)
            if self.save_data(data, symbol):
                successful_downloads += 1
            else:
                failed_downloads.append(symbol)
                
        self.logger.info(f"Download complete: {successful_downloads} successful, {len(failed_downloads)} failed")
        
        if failed_downloads:
            self.logger.warning(f"Failed downloads: {failed_downloads}")
            
        return successful_downloads, failed_downloads
        
    def get_latest_data(self, symbol, days=5):
        """Get latest data for a symbol (last N days)."""
        try:
            ticker = yf.Ticker(symbol)
            end_date = datetime.now()
            start_date = end_date - timedelta(days=days)
            
            data = ticker.history(start=start_date, end=end_date)
            data['Symbol'] = symbol
            data.reset_index(inplace=True)
            
            return data
            
        except Exception as e:
            self.logger.error(f"Error getting latest data for {symbol}: {e}")
            return None


def main():
    parser = argparse.ArgumentParser(description='Download market data using yfinance')
    parser.add_argument('--symbols', nargs='+', help='Specific symbols to download')
    parser.add_argument('--period', default=None, help='Data period (1d, 1mo, 1y, etc.)')
    parser.add_argument('--interval', default=None, help='Data interval (1d, 1h, etc.)')
    parser.add_argument('--config', default='config/symbols.yaml', help='Config file path')
    
    args = parser.parse_args()
    
    # Initialize downloader
    downloader = MarketDataDownloader(args.config)
    
    # Download data
    if args.symbols:
        downloader.download_all_symbols(args.symbols)
    else:
        downloader.download_all_symbols()


if __name__ == "__main__":
    main()
