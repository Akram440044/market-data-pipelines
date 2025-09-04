#!/bin/zsh
#
# Market Data Pipeline Monitor
# Monitors data quality, system health, and sends alerts
#

set -e

# Script configuration
if [[ -n "${ZSH_VERSION}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
CONFIG_FILE="${SCRIPT_DIR}/config/symbols.yaml"
LOG_DIR="${SCRIPT_DIR}/logs"
DATA_DIR="${SCRIPT_DIR}/data"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Monitor log file
MONITOR_LOG="${LOG_DIR}/monitor_$(date +%Y%m%d).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log and display messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${message}" | tee -a "${MONITOR_LOG}"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${message}" | tee -a "${MONITOR_LOG}"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${message}" | tee -a "${MONITOR_LOG}"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} ${message}" | tee -a "${MONITOR_LOG}"
            ;;
    esac
    
    echo "${timestamp} [${level}] ${message}" >> "${MONITOR_LOG}"
}

# Function to send alert
send_alert() {
    local alert_level=$1
    local message=$2
    
    log_message "${alert_level}" "ALERT: ${message}"
    
    # Try to send email notification if available
    if command -v mail >/dev/null 2>&1; then
        echo "Market Data Pipeline Alert - ${alert_level}: ${message}" | \
        mail -s "Market Data Alert - ${alert_level}" "${USER}@$(hostname)" 2>/dev/null || true
    fi
    
    # You could add other notification methods here:
    # - Slack webhook
    # - Discord webhook  
    # - SMS via API
    # - Push notification
}

# Function to check data freshness
check_data_freshness() {
    log_message "INFO" "Checking data freshness..."
    
    local current_time=$(date +%s)
    local max_age_hours=24
    local max_age_seconds=$((max_age_hours * 3600))
    
    local stale_files=0
    local total_files=0
    
    # Check raw data files
    for file in "${DATA_DIR}"/*.csv; do
        if [[ -f "$file" ]]; then
            total_files=$((total_files + 1))
            local file_time=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
            local age=$((current_time - file_time))
            
            if [[ $age -gt $max_age_seconds ]]; then
                stale_files=$((stale_files + 1))
                local hours_old=$((age / 3600))
                log_message "WARN" "Stale data file: $(basename "$file") (${hours_old}h old)"
            fi
        fi
    done
    
    if [[ $stale_files -gt 0 ]]; then
        send_alert "WARN" "${stale_files}/${total_files} data files are older than ${max_age_hours} hours"
    else
        log_message "INFO" "All data files are fresh (${total_files} files checked)"
    fi
    
    return $stale_files
}

# Function to check data quality
check_data_quality() {
    log_message "INFO" "Checking data quality..."
    
    local quality_issues=0
    
    # Check if we have data files
    local data_file_count=$(find "${DATA_DIR}" -name "*.csv" -type f | wc -l)
    if [[ $data_file_count -eq 0 ]]; then
        send_alert "ERROR" "No data files found"
        return 1
    fi
    
    # Use Python to check data quality
    python3 << EOF
import pandas as pd
import glob
import sys
import os
from pathlib import Path

data_dir = Path("${DATA_DIR}")
quality_issues = 0

# Check each CSV file
for csv_file in data_dir.glob("*.csv"):
    try:
        df = pd.read_csv(csv_file)
        symbol = csv_file.stem.split('_')[0]
        
        # Check if file is empty
        if df.empty:
            print(f"WARN: Empty data file: {csv_file.name}")
            quality_issues += 1
            continue
            
        # Check for required columns
        required_cols = ['Date', 'Open', 'High', 'Low', 'Close', 'Volume']
        missing_cols = [col for col in required_cols if col not in df.columns]
        if missing_cols:
            print(f"ERROR: Missing columns in {csv_file.name}: {missing_cols}")
            quality_issues += 1
            continue
            
        # Check for null values in critical columns
        critical_nulls = df[['Close', 'Volume']].isnull().sum().sum()
        if critical_nulls > 0:
            print(f"WARN: {critical_nulls} null values in critical columns for {symbol}")
            quality_issues += 1
            
        # Check for unrealistic values
        if (df['Close'] <= 0).any():
            print(f"ERROR: Invalid price data (<=0) found in {symbol}")
            quality_issues += 1
            
        if (df['Volume'] < 0).any():
            print(f"ERROR: Negative volume found in {symbol}")
            quality_issues += 1
            
        # Check for data gaps (missing dates)
        df['Date'] = pd.to_datetime(df['Date'])
        df = df.sort_values('Date')
        date_diffs = df['Date'].diff().dt.days
        large_gaps = date_diffs[date_diffs > 7].count()  # More than 7 days gap
        if large_gaps > 0:
            print(f"WARN: {large_gaps} large date gaps (>7 days) found in {symbol}")
            quality_issues += 1
            
    except Exception as e:
        print(f"ERROR: Failed to check {csv_file.name}: {e}")
        quality_issues += 1

print(f"INFO: Data quality check completed. Issues found: {quality_issues}")
sys.exit(quality_issues)
EOF
    
    local python_exit_code=$?
    
    if [[ $python_exit_code -gt 0 ]]; then
        send_alert "ERROR" "${python_exit_code} data quality issues detected"
        return $python_exit_code
    else
        log_message "INFO" "Data quality check passed"
        return 0
    fi
}

# Function to check disk usage
check_disk_usage() {
    log_message "INFO" "Checking disk usage..."
    
    # Get disk usage for the pipeline directory
    local usage_info=$(df -h "${SCRIPT_DIR}" | tail -1)
    local usage_percent=$(echo "$usage_info" | awk '{print $5}' | sed 's/%//')
    local available_space=$(echo "$usage_info" | awk '{print $4}')
    
    log_message "INFO" "Disk usage: ${usage_percent}% used, ${available_space} available"
    
    # Alert if usage is high
    if [[ $usage_percent -gt 90 ]]; then
        send_alert "ERROR" "Disk usage critical: ${usage_percent}% used, only ${available_space} available"
        return 1
    elif [[ $usage_percent -gt 80 ]]; then
        send_alert "WARN" "Disk usage high: ${usage_percent}% used, ${available_space} available"
        return 1
    fi
    
    return 0
}

# Function to check pipeline processes
check_pipeline_health() {
    log_message "INFO" "Checking pipeline health..."
    
    local issues=0
    local venv_dir="${SCRIPT_DIR}/venv"
    
    # Check if Python is available
    if ! command -v python3 >/dev/null 2>&1; then
        send_alert "ERROR" "Python 3 not available"
        issues=$((issues + 1))
    fi
    
    # Activate virtual environment if available
    if [[ -d "$venv_dir" ]]; then
        source "${venv_dir}/bin/activate"
        log_message "INFO" "Using virtual environment for health check"
    else
        log_message "WARN" "Virtual environment not found - using system Python"
    fi
    
    # Check Python dependencies
    local required_packages=("yfinance" "pandas" "numpy" "yaml" "jinja2")
    for package in "${required_packages[@]}"; do
        if ! python -c "import ${package}" 2>/dev/null; then
            send_alert "ERROR" "Missing Python package: ${package}"
            issues=$((issues + 1))
        fi
    done
    
    # Check if configuration file exists and is valid
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        send_alert "ERROR" "Configuration file not found: ${CONFIG_FILE}"
        issues=$((issues + 1))
    else
        # Try to parse YAML
        if ! python3 -c "import yaml; yaml.safe_load(open('${CONFIG_FILE}'))" 2>/dev/null; then
            send_alert "ERROR" "Invalid YAML in configuration file"
            issues=$((issues + 1))
        fi
    fi
    
    return $issues
}

# Function to monitor log files for errors
check_recent_errors() {
    log_message "INFO" "Checking recent log files for errors..."
    
    local error_count=0
    local recent_logs=$(find "${LOG_DIR}" -name "*.log" -mtime -1 -type f)
    
    if [[ -z "$recent_logs" ]]; then
        log_message "WARN" "No recent log files found"
        return 0
    fi
    
    for log_file in $recent_logs; do
        local errors_in_file=$(grep -c "ERROR" "$log_file" 2>/dev/null || echo "0")
        if [[ $errors_in_file -gt 0 ]]; then
            error_count=$((error_count + errors_in_file))
            log_message "WARN" "Found ${errors_in_file} errors in $(basename "$log_file")"
            
            # Show recent errors
            log_message "DEBUG" "Recent errors from $(basename "$log_file"):"
            grep "ERROR" "$log_file" | tail -3 | while read -r line; do
                log_message "DEBUG" "  $line"
            done
        fi
    done
    
    if [[ $error_count -gt 0 ]]; then
        send_alert "WARN" "Found ${error_count} errors in recent log files"
        return 1
    else
        log_message "INFO" "No recent errors found in log files"
        return 0
    fi
}

# Function to generate monitoring report
generate_monitoring_report() {
    log_message "INFO" "Generating monitoring report..."
    
    local report_file="${SCRIPT_DIR}/reports/monitoring_report_$(date +%Y%m%d_%H%M).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Market Data Pipeline - Monitoring Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 20px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .status.ok { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .status.warn { background-color: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
        .status.error { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #f8f9fa; border-radius: 5px; min-width: 120px; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Market Data Pipeline Monitoring</h1>
            <h2>$(date)</h2>
        </div>
        
        <h3>System Status</h3>
        <div class="status ok">Pipeline is operational</div>
        
        <h3>Quick Metrics</h3>
        <div class="metric">
            <strong>Data Files</strong><br>
            $(find "${DATA_DIR}" -name "*.csv" -type f | wc -l)
        </div>
        <div class="metric">
            <strong>Disk Usage</strong><br>
            $(df -h "${SCRIPT_DIR}" | tail -1 | awk '{print $5}')
        </div>
        <div class="metric">
            <strong>Last Run</strong><br>
            $(find "${LOG_DIR}" -name "pipeline_run_*.log" -type f -exec ls -t {} \; | head -1 | xargs basename | cut -d_ -f3-4 | cut -d. -f1 || echo "Never")
        </div>
        
        <h3>Recent Activity</h3>
        <pre>$(tail -20 "${MONITOR_LOG}" 2>/dev/null || echo "No monitor log available")</pre>
        
        <div style="margin-top: 20px; text-align: center; font-size: 12px; color: #666;">
            Report generated at $(date)
        </div>
    </div>
</body>
</html>
EOF
    
    log_message "INFO" "Monitoring report saved to: $report_file"
    echo "$report_file"
}

# Function to run all monitoring checks
run_all_checks() {
    log_message "INFO" "Starting comprehensive monitoring checks..."
    
    local total_issues=0
    
    # Run all checks
    check_pipeline_health || total_issues=$((total_issues + $?))
    check_data_freshness || total_issues=$((total_issues + $?))
    check_data_quality || total_issues=$((total_issues + $?))
    check_disk_usage || total_issues=$((total_issues + $?))
    check_recent_errors || total_issues=$((total_issues + $?))
    
    # Summary
    if [[ $total_issues -eq 0 ]]; then
        log_message "INFO" "All monitoring checks passed successfully"
        send_alert "INFO" "All systems operational - monitoring checks passed"
    else
        log_message "ERROR" "Monitoring found ${total_issues} issues"
        send_alert "ERROR" "Monitoring detected ${total_issues} issues requiring attention"
    fi
    
    # Generate report
    local report_path=$(generate_monitoring_report)
    
    return $total_issues
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND]

Market Data Pipeline Monitor

COMMANDS:
    health      Check pipeline health and dependencies
    data        Check data quality and freshness  
    disk        Check disk usage
    errors      Check recent log files for errors
    report      Generate monitoring report
    all         Run all monitoring checks (default)

EXAMPLES:
    $0              # Run all checks
    $0 all          # Run all checks
    $0 health       # Check system health only
    $0 data         # Check data quality only
    $0 report       # Generate monitoring report

EOF
}

# Main execution
main() {
    local command="all"
    
    if [[ $# -gt 0 ]]; then
        command="$1"
    fi
    
    case "$command" in
        "health")
            check_pipeline_health
            ;;
        "data")
            check_data_freshness
            check_data_quality
            ;;
        "disk")
            check_disk_usage
            ;;
        "errors")
            check_recent_errors
            ;;
        "report")
            generate_monitoring_report
            ;;
        "all")
            run_all_checks
            ;;
        "-h"|"--help"|"help")
            show_usage
            ;;
        *)
            echo "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
