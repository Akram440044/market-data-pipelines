#!/bin/zsh
#
# Market Data Pipeline Runner
# Orchestrates the complete market data pipeline
#

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Script configuration
if [[ -n "${ZSH_VERSION}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
CONFIG_FILE="${SCRIPT_DIR}/config/symbols.yaml"
LOG_DIR="${SCRIPT_DIR}/logs"
PYTHON_SCRIPTS="${SCRIPT_DIR}/scripts"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Log file for this run
RUN_LOG="${LOG_DIR}/pipeline_run_$(date +%Y%m%d_%H%M%S).log"

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
            echo -e "${GREEN}[INFO]${NC} ${message}" | tee -a "${RUN_LOG}"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${message}" | tee -a "${RUN_LOG}"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${message}" | tee -a "${RUN_LOG}"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} ${message}" | tee -a "${RUN_LOG}"
            ;;
    esac
    
    echo "${timestamp} [${level}] ${message}" >> "${RUN_LOG}"
}

# Function to check if Python script exists
check_script() {
    local script_path=$1
    if [[ ! -f "${script_path}" ]]; then
        log_message "ERROR" "Script not found: ${script_path}"
        exit 1
    fi
}

# Function to activate virtual environment
activate_venv() {
    local venv_dir="${SCRIPT_DIR}/venv"
    if [[ -d "$venv_dir" ]]; then
        source "${venv_dir}/bin/activate"
        log_message "INFO" "Activated virtual environment"
    else
        log_message "WARN" "Virtual environment not found at ${venv_dir}"
        log_message "INFO" "Run ./setup.sh to create it"
    fi
}

# Function to check Python dependencies
check_dependencies() {
    log_message "INFO" "Checking Python dependencies..."
    
    # Activate virtual environment first
    activate_venv
    
    local required_packages=("yfinance" "pandas" "numpy" "yaml" "jinja2")
    
    for package in "${required_packages[@]}"; do
        if ! python -c "import ${package}" 2>/dev/null; then
            log_message "ERROR" "Missing Python package: ${package}"
            log_message "INFO" "Install with: pip install ${package}"
            log_message "INFO" "Or run: ./setup.sh --deps"
            exit 1
        fi
    done
    
    log_message "INFO" "All dependencies satisfied"
}

# Function to download market data
download_data() {
    local symbols=("$@")
    
    log_message "INFO" "Starting data download..."
    
    local download_script="${PYTHON_SCRIPTS}/data_downloader.py"
    check_script "${download_script}"
    
    # Ensure virtual environment is activated
    activate_venv
    
    if [[ ${#symbols[@]} -gt 0 ]]; then
        log_message "INFO" "Downloading data for specific symbols: ${symbols[*]}"
        python "${download_script}" --symbols "${symbols[@]}" --config "${CONFIG_FILE}"
    else
        log_message "INFO" "Downloading data for all configured symbols"
        python "${download_script}" --config "${CONFIG_FILE}"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Data download completed successfully"
        return 0
    else
        log_message "ERROR" "Data download failed"
        return 1
    fi
}

# Function to process market data
process_data() {
    log_message "INFO" "Starting data processing..."
    
    local processor_script="${PYTHON_SCRIPTS}/data_processor.py"
    check_script "${processor_script}"
    
    # Ensure virtual environment is activated
    activate_venv
    
    python "${processor_script}"
    
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Data processing completed successfully"
        return 0
    else
        log_message "ERROR" "Data processing failed"
        return 1
    fi
}

# Function to generate reports
generate_report() {
    local symbols=("$@")
    
    log_message "INFO" "Starting report generation..."
    
    local report_script="${PYTHON_SCRIPTS}/report_generator.py"
    check_script "${report_script}"
    
    # Ensure virtual environment is activated
    activate_venv
    
    if [[ ${#symbols[@]} -gt 0 ]]; then
        log_message "INFO" "Generating report for specific symbols: ${symbols[*]}"
        python "${report_script}" --symbols "${symbols[@]}" --config "${CONFIG_FILE}"
    else
        log_message "INFO" "Generating report for all symbols"
        python "${report_script}" --config "${CONFIG_FILE}"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_message "INFO" "Report generation completed successfully"
        return 0
    else
        log_message "ERROR" "Report generation failed"
        return 1
    fi
}

# Function to send email notification (if mail is configured)
send_notification() {
    local subject=$1
    local message=$2
    
    # Check if mail command is available
    if command -v mail >/dev/null 2>&1; then
        # This assumes mail is configured on the system
        echo "${message}" | mail -s "${subject}" "${USER}@$(hostname)" 2>/dev/null || true
        log_message "INFO" "Email notification attempted"
    else
        log_message "DEBUG" "Mail command not available, skipping email notification"
    fi
}

# Function to open report in browser
open_report() {
    local report_file=$(find "${SCRIPT_DIR}/reports" -name "market_report_*.html" -type f -exec ls -t {} \; | head -1)
    
    if [[ -f "${report_file}" ]]; then
        log_message "INFO" "Opening latest report: $(basename "${report_file}")"
        
        # Try to open in default browser
        if command -v open >/dev/null 2>&1; then  # macOS
            open "${report_file}"
        elif command -v xdg-open >/dev/null 2>&1; then  # Linux
            xdg-open "${report_file}"
        else
            log_message "INFO" "Report saved at: ${report_file}"
        fi
    else
        log_message "WARN" "No report file found to open"
    fi
}

# Function to cleanup old files
cleanup_old_files() {
    local days_to_keep=${1:-7}
    
    log_message "INFO" "Cleaning up files older than ${days_to_keep} days..."
    
    # Clean old data files (keep processed files longer)
    find "${SCRIPT_DIR}/data" -name "*.csv" -mtime +${days_to_keep} -not -path "*/processed/*" -delete 2>/dev/null || true
    
    # Clean old processed files (keep longer)
    find "${SCRIPT_DIR}/data/processed" -name "*.csv" -mtime +$((days_to_keep * 2)) -delete 2>/dev/null || true
    
    # Clean old logs
    find "${LOG_DIR}" -name "*.log" -mtime +${days_to_keep} -delete 2>/dev/null || true
    
    # Clean old reports (keep longer)
    find "${SCRIPT_DIR}/reports" -name "*.html" -mtime +$((days_to_keep * 3)) -delete 2>/dev/null || true
    
    log_message "INFO" "Cleanup completed"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Market Data Pipeline Runner

COMMANDS:
    download    Download market data only
    process     Process downloaded data only
    report      Generate reports only
    full        Run complete pipeline (default)
    cleanup     Clean up old files
    health      Check system health

OPTIONS:
    -s, --symbols SYMBOLS   Comma-separated list of symbols (e.g., AAPL,GOOGL,MSFT)
    -c, --config FILE       Configuration file (default: config/symbols.yaml)
    -o, --open              Open report in browser after generation
    -q, --quiet             Suppress output (logs still written)
    -h, --help              Show this help message

EXAMPLES:
    $0                           # Run full pipeline
    $0 full                      # Run full pipeline  
    $0 download                  # Download data only
    $0 --symbols AAPL,GOOGL      # Run pipeline for specific symbols
    $0 report --open             # Generate report and open in browser
    $0 cleanup                   # Clean up old files

EOF
}

# Function to check system health
check_health() {
    log_message "INFO" "Running system health check..."
    
    local health_status=0
    
    # Check Python installation
    if ! command -v python3 >/dev/null 2>&1; then
        log_message "ERROR" "Python 3 not found"
        health_status=1
    else
        log_message "INFO" "Python 3: $(python3 --version)"
    fi
    
    # Check dependencies
    check_dependencies || health_status=1
    
    # Check configuration file
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_message "ERROR" "Configuration file not found: ${CONFIG_FILE}"
        health_status=1
    else
        log_message "INFO" "Configuration file: OK"
    fi
    
    # Check directory structure
    local required_dirs=("scripts" "data" "logs" "reports" "config")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${SCRIPT_DIR}/${dir}" ]]; then
            log_message "ERROR" "Required directory not found: ${dir}"
            health_status=1
        else
            log_message "INFO" "Directory ${dir}: OK"
        fi
    done
    
    # Check disk space (warn if less than 1GB available)
    local available_space=$(df "${SCRIPT_DIR}" | tail -1 | awk '{print $4}')
    if [[ ${available_space} -lt 1048576 ]]; then  # 1GB in KB
        log_message "WARN" "Low disk space: $((available_space / 1024))MB available"
    else
        log_message "INFO" "Disk space: OK"
    fi
    
    if [[ ${health_status} -eq 0 ]]; then
        log_message "INFO" "System health check passed"
    else
        log_message "ERROR" "System health check failed"
    fi
    
    return ${health_status}
}

# Main execution function
main() {
    local command="full"
    local symbols=()
    local open_report=false
    local quiet=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--symbols)
                if [[ -n "${ZSH_VERSION}" ]]; then
                    symbols=(${(s/,/)2})
                else
                    IFS=',' read -ra symbols <<< "$2"
                fi
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -o|--open)
                open_report=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            download|process|report|full|cleanup|health)
                command="$1"
                shift
                ;;
            *)
                log_message "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Redirect output if quiet mode
    if [[ "${quiet}" == "true" ]]; then
        exec 1>/dev/null
    fi
    
    log_message "INFO" "Starting Market Data Pipeline - Command: ${command}"
    log_message "INFO" "Script directory: ${SCRIPT_DIR}"
    log_message "INFO" "Configuration: ${CONFIG_FILE}"
    
    case "${command}" in
        "health")
            check_health
            exit $?
            ;;
        "cleanup")
            cleanup_old_files
            exit 0
            ;;
        "download")
            check_dependencies
            download_data "${symbols[@]}"
            ;;
        "process")
            process_data
            ;;
        "report")
            generate_report "${symbols[@]}"
            if [[ "${open_report}" == "true" ]]; then
                open_report
            fi
            ;;
        "full")
            check_dependencies
            
            # Run complete pipeline
            if download_data "${symbols[@]}"; then
                if process_data; then
                    if generate_report "${symbols[@]}"; then
                        log_message "INFO" "Complete pipeline executed successfully"
                        
                        if [[ "${open_report}" == "true" ]]; then
                            open_report
                        fi
                        
                        # Send success notification
                        send_notification "Market Data Pipeline Success" "Pipeline completed successfully at $(date)"
                    else
                        log_message "ERROR" "Pipeline failed at report generation stage"
                        exit 1
                    fi
                else
                    log_message "ERROR" "Pipeline failed at data processing stage"
                    exit 1
                fi
            else
                log_message "ERROR" "Pipeline failed at data download stage"
                exit 1
            fi
            ;;
    esac
    
    log_message "INFO" "Pipeline execution completed"
}

# Trap to handle script interruption
trap 'log_message "WARN" "Pipeline execution interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"
