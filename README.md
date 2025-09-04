# Market Data Pipeline - Two Versions Available

A comprehensive shell-based market data pipeline for quantitative finance analysis. This system downloads stock data, calculates technical indicators, and generates professional reports - all orchestrated through shell scripts.

## 🔄 Two Versions Available

### 1. **Modern uv Version** ([`uv-version/`](./uv-version/))
- **Ultra-fast package management** with uv (10-100x faster than pip)
- **Modern dependency resolution** with lockfiles
- **Reproducible builds** with `pyproject.toml` and `uv.lock`
- **Best for**: Modern environments, performance-focused teams

### 2. **Standard venv Version** ([`venv-version/`](./venv-version/))
- **Universal compatibility** with standard Python tools
- **Traditional pip workflow** familiar to all Python developers
- **No additional tools required** - uses built-in `venv`
- **Best for**: Maximum compatibility, traditional workflows

## 📊 Version Comparison

| Feature | venv Version | uv Version |
|---------|-------------|------------|
| **Package Manager** | pip | uv (10-100x faster) |
| **Virtual Environment** | `venv/` | `.venv/` |
| **Setup Speed** | Moderate (30-60s) | Very Fast (5-15s) |
| **Dependency Resolution** | Basic | Advanced with conflict detection |
| **Lockfile** | requirements.txt | uv.lock + pyproject.toml |
| **Compatibility** | Universal | Modern (Python 3.8+) |
| **Installation** | Built into Python | Requires `curl -LsSf https://astral.sh/uv/install.sh | sh` |
| **Team Adoption** | Immediate | May require onboarding |

## 🚀 Quick Start (Choose Your Version)

### Option A: Modern uv Version
```bash
cd uv-version/
./setup.sh
source activate_env.sh
./run_pipeline.sh full
```

### Option B: Standard venv Version  
```bash
cd venv-version/
./setup.sh
source activate_env.sh
./run_pipeline.sh full
```

## 🛠️ Core Features (Both Versions)

### Market Data Pipeline
- **Data Download**: Yahoo Finance integration with yfinance
- **Technical Analysis**: RSI, MACD, Bollinger Bands, Moving Averages
- **Professional Reports**: HTML reports with market summaries
- **System Monitoring**: Health checks and data quality validation
- **Shell Orchestration**: Complete automation with error handling

### Technical Indicators Calculated
- Simple Moving Averages (SMA 20, 50)
- Exponential Moving Average (EMA 20)
- Relative Strength Index (RSI)
- Bollinger Bands
- MACD with signal line and histogram
- Volume indicators (OBV, volume ratios)
- Rolling volatility
- Support/resistance levels

### Automated Features
- Daily market data download
- Technical indicator calculation
- HTML report generation with styling
- Alert system for unusual activity
- Data quality monitoring
- System health checks
- Error logging and recovery

## 📈 Use Cases in Quantitative Finance

- **Research & Backtesting**: Historical data preparation
- **Risk Management**: Daily position monitoring and alerts  
- **Automated Reporting**: Team market summaries
- **Data Quality Assurance**: Clean, validated datasets
- **Operational Monitoring**: Pipeline health and reliability

## 🎯 Recommendation

**For New Projects**: Start with the **uv version** for speed and modern tooling
**For Existing Teams**: Use the **venv version** for immediate compatibility
**For Learning**: Either version works - choose based on your Python experience

Both versions provide identical functionality - the choice depends on your environment and preferences.

## 📚 Documentation

Each version includes:
- Complete README with setup instructions
- Shell script documentation  
- Configuration examples
- Troubleshooting guides
- GitHub publishing instructions

---

**Built for quantitative developers who need reliable, automated market data pipelines.** 🚀📊
