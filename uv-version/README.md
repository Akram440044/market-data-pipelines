# Market Data Pipeline

A comprehensive shell-based market data pipeline for quantitative finance analysis. This system downloads stock data, calculates technical indicators, and generates professional reports - all orchestrated through shell scripts.

## 🚀 Quick Start

```bash
# 1. Set up the pipeline
./setup.sh

# 2. Activate the environment
source ./activate_env.sh

# 3. Run your first pipeline
./run_pipeline.sh full

# 4. Check system health
./monitor.sh
```

## 📁 Project Structure

```
market-data-pipeline/
├── 📄 README.md              # Documentation
├── 🔧 setup.sh               # Setup script
├── 🚀 run_pipeline.sh        # Main pipeline orchestrator
├── 📊 monitor.sh             # System monitoring
├── 📋 requirements.txt       # Python dependencies
├── 📁 config/                # Configuration files
│   └── symbols.yaml          # Stock symbols and settings
├── 📁 scripts/               # Python processing scripts
│   ├── data_downloader.py    # Yahoo Finance data downloader
│   ├── data_processor.py     # Technical indicators calculator
│   └── report_generator.py   # HTML report generator
├── 📁 data/                  # Raw market data (CSV)
│   └── processed/            # Processed data with indicators
├── 📁 reports/               # Generated HTML reports
├── 📁 logs/                  # System and execution logs
└── 📁 venv/                  # Python virtual environment
```

## 🛠️ Components

### 1. Data Downloader (`data_downloader.py`)
- Downloads historical stock data using yfinance
- Configurable time periods and intervals
- Robust error handling and logging
- Supports individual symbols or batch processing

### 2. Data Processor (`data_processor.py`)
- Calculates technical indicators:
  - Simple/Exponential Moving Averages (SMA/EMA)
  - Relative Strength Index (RSI)
  - Bollinger Bands
  - MACD (Moving Average Convergence Divergence)
  - Volume indicators and volatility metrics
- Processes data and saves enhanced datasets

### 3. Report Generator (`report_generator.py`)
- Creates professional HTML reports
- Market summary with top gainers/losers
- Technical analysis for significant movers
- Responsive design with visual indicators
- Alert system for unusual activity

### 4. Pipeline Orchestrator (`run_pipeline.sh`)
- Coordinates the entire workflow
- Health checks and dependency validation
- Flexible execution modes
- Comprehensive logging and error handling

### 5. System Monitor (`monitor.sh`)
- Data quality and freshness checks
- Disk usage monitoring
- Error log analysis
- Health status reports

## 📊 Features

### Technical Indicators
- **Moving Averages**: SMA(20), SMA(50), EMA(20)
- **Momentum**: RSI(14), MACD(12,26,9)
- **Volatility**: Bollinger Bands, rolling volatility
- **Volume**: OBV, volume ratios, volume moving averages
- **Price Action**: Daily returns, price changes, H-L spreads

### Automated Reporting
- Top gainers and losers identification
- High volume activity detection
- Technical signal analysis
- Support/resistance level calculation
- Trend analysis using moving averages

### Alert System
- Price movement alerts (>5% default)
- Volume spike detection (2x average)
- Data quality warnings
- System health notifications

## 🚀 Usage

### Basic Commands

```bash
# Run complete pipeline
./run_pipeline.sh

# Download data only
./run_pipeline.sh download

# Process existing data
./run_pipeline.sh process

# Generate reports only
./run_pipeline.sh report

# Check system health
./run_pipeline.sh health
```

### Advanced Usage

```bash
# Process specific symbols
./run_pipeline.sh --symbols AAPL,GOOGL,MSFT

# Generate report and open in browser
./run_pipeline.sh report --open

# Run in quiet mode (logs only)
./run_pipeline.sh --quiet

# Use custom configuration
./run_pipeline.sh --config custom_config.yaml
```

### Monitoring Commands

```bash
# Full system check
./monitor.sh

# Check data quality only
./monitor.sh data

# Check system health
./monitor.sh health

# Generate monitoring report
./monitor.sh report
```

## ⚙️ Configuration

Edit `config/symbols.yaml` to customize:

```yaml
symbols:
  - AAPL    # Apple Inc.
  - GOOGL   # Alphabet Inc.
  - MSFT    # Microsoft Corp.
  # Add your preferred symbols

data_settings:
  period: "1y"      # 1d, 5d, 1mo, 3mo, 6mo, 1y, 2y, 5y, 10y
  interval: "1d"    # 1m, 2m, 5m, 15m, 30m, 60m, 90m, 1h, 1d, 5d, 1wk, 1mo

alerts:
  price_change_threshold: 5.0    # Alert threshold (%)
  volume_multiplier: 2.0         # Volume spike multiplier
```

## 🔄 Automation

### Cron Job Setup

```bash
# Edit crontab
crontab -e

# Add daily execution at 6 PM (after market close)
0 18 * * 1-5 cd /path/to/market-data-pipeline && ./run_pipeline.sh full

# Add monitoring check every hour during market hours
0 9-16 * * 1-5 cd /path/to/market-data-pipeline && ./monitor.sh
```

### Systemd Timer (Linux)

Create `/etc/systemd/system/market-data-pipeline.service`:

```ini
[Unit]
Description=Market Data Pipeline
After=network.target

[Service]
Type=oneshot
User=your-username
WorkingDirectory=/path/to/market-data-pipeline
ExecStart=/path/to/market-data-pipeline/run_pipeline.sh full
```

Create `/etc/systemd/system/market-data-pipeline.timer`:

```ini
[Unit]
Description=Run Market Data Pipeline Daily
Requires=market-data-pipeline.service

[Timer]
OnCalendar=Mon-Fri 18:00
Persistent=true

[Install]
WantedBy=timers.target
```

## 🔧 Troubleshooting

### Common Issues

1. **Missing Python packages**
   ```bash
   # Reinstall dependencies
   ./setup.sh --deps
   ```

2. **Data download failures**
   ```bash
   # Check internet connection and run health check
   ./run_pipeline.sh health
   ```

3. **Permission errors**
   ```bash
   # Fix script permissions
   chmod +x *.sh
   find scripts/ -name "*.py" -exec chmod +x {} \;
   ```

4. **Virtual environment issues**
   ```bash
   # Recreate virtual environment
   rm -rf venv/
   ./setup.sh --venv
   ```

### Logging

All operations are logged to:
- `logs/pipeline_run_YYYYMMDD_HHMMSS.log` - Pipeline execution
- `logs/data_download_YYYYMMDD.log` - Data download activities
- `logs/data_processing_YYYYMMDD.log` - Data processing
- `logs/report_generation_YYYYMMDD.log` - Report generation
- `logs/monitor_YYYYMMDD.log` - Monitoring activities

## 📈 Use Cases in Quantitative Finance

This pipeline addresses common needs in quantitative development:

1. **Research & Backtesting**: Historical data preparation for strategy development
2. **Risk Management**: Daily monitoring of portfolio positions and alerts
3. **Reporting**: Automated generation of market summaries for teams
4. **Data Quality**: Ensuring clean, validated data for downstream analysis
5. **Operational Monitoring**: System health checks and data pipeline reliability

## 🔐 Security & Best Practices

- All sensitive data stays local (no cloud dependencies)
- Virtual environment isolation
- Comprehensive logging for audit trails
- Error handling and graceful degradation
- Automated cleanup of old files
- Configuration-driven approach

## 📚 Dependencies

### Core Python Packages
- `pandas` - Data manipulation and analysis
- `numpy` - Numerical computing
- `yfinance` - Yahoo Finance data API
- `PyYAML` - Configuration file parsing
- `Jinja2` - HTML template rendering

### Optional Packages
- `matplotlib/seaborn` - Data visualization
- `scipy` - Scientific computing
- `TA-Lib` - Technical analysis library
- `SQLAlchemy` - Database integration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙋‍♂️ Support

For issues and questions:
1. Check the troubleshooting section
2. Review the logs in the `logs/` directory
3. Run `./monitor.sh` for system health status
4. Run `./run_pipeline.sh health` for dependency checks

---

**Built for quantitative developers who need reliable, automated market data pipelines.** 🚀📊
