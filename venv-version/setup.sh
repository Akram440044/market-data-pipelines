#!/bin/zsh
#
# Market Data Pipeline Setup Script
# Sets up the environment and installs dependencies
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
if [[ -n "${ZSH_VERSION}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Function to print colored output
print_status() {
    local level=$1
    local message=$2
    
    case $level in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${message}"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${message}"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${message}"
            ;;
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} ${message}"
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Python installation
check_python() {
    print_status "INFO" "Checking Python installation..."
    
    if ! command_exists python3; then
        print_status "ERROR" "Python 3 is required but not installed"
        print_status "INFO" "Please install Python 3 first:"
        print_status "INFO" "  macOS: brew install python3"
        print_status "INFO" "  Linux: apt-get install python3 python3-pip"
        exit 1
    fi
    
    local python_version=$(python3 --version | cut -d' ' -f2)
    print_status "INFO" "Python version: ${python_version}"
    
    # Check minimum version (3.8+)
    if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)"; then
        print_status "ERROR" "Python 3.8 or higher is required"
        exit 1
    fi
    
    # Check pip
    if ! command_exists pip3; then
        print_status "ERROR" "pip3 is required but not installed"
        exit 1
    fi
    
    print_status "INFO" "Python environment OK"
}

# Function to create virtual environment
setup_virtual_env() {
    print_status "INFO" "Setting up standard Python virtual environment..."
    
    local venv_dir="${SCRIPT_DIR}/venv"
    
    if [[ -d "$venv_dir" ]]; then
        print_status "INFO" "Virtual environment already exists"
        echo -n "Do you want to recreate it? (y/N): "
        read -r REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$venv_dir"
            print_status "INFO" "Removed existing virtual environment"
        else
            print_status "INFO" "Using existing virtual environment"
            return 0
        fi
    fi
    
    python3 -m venv "$venv_dir"
    print_status "INFO" "Created virtual environment at ${venv_dir}"
    
    # Activate virtual environment
    source "${venv_dir}/bin/activate"
    
    # Upgrade pip and install wheel
    print_status "INFO" "Upgrading pip and installing build tools..."
    pip install --upgrade pip setuptools wheel
    
    print_status "INFO" "Virtual environment setup complete"
}

# Function to install Python dependencies
install_dependencies() {
    print_status "INFO" "Installing Python dependencies..."
    
    local requirements_file="${SCRIPT_DIR}/requirements.txt"
    local venv_dir="${SCRIPT_DIR}/venv"
    
    if [[ ! -f "$requirements_file" ]]; then
        print_status "ERROR" "Requirements file not found: ${requirements_file}"
        exit 1
    fi
    
    # Activate virtual environment
    if [[ -d "$venv_dir" ]]; then
        source "${venv_dir}/bin/activate"
        print_status "INFO" "Activated virtual environment"
    else
        print_status "ERROR" "Virtual environment not found. Run setup first."
        exit 1
    fi
    
    # Install core dependencies
    print_status "INFO" "Installing core dependencies with pip..."
    pip install pandas numpy yfinance PyYAML Jinja2
    
    # Ask about optional dependencies
    print_status "INFO" "Core dependencies installed successfully"
    
    echo -n "Do you want to install optional dependencies (plotting, advanced analysis)? (y/N): "
    read -r REPLY
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "INFO" "Installing optional dependencies..."
        
        # Install optional dependencies with error handling
        local optional_deps=("scipy" "matplotlib" "seaborn" "loguru")
        
        for dep in "${optional_deps[@]}"; do
            print_status "INFO" "Installing ${dep}..."
            if pip install "$dep"; then
                print_status "INFO" "${dep} installed successfully"
            else
                print_status "WARN" "Failed to install ${dep} (skipping)"
            fi
        done
        
        # Handle TA-Lib separately as it often requires compilation
        echo -n "Do you want to install TA-Lib for advanced technical analysis? (requires compilation) (y/N): "
        read -r REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "INFO" "Installing TA-Lib..."
            if pip install TA-Lib; then
                print_status "INFO" "TA-Lib installed successfully"
            else
                print_status "WARN" "Failed to install TA-Lib"
                print_status "INFO" "You may need to install TA-Lib system dependencies first:"
                print_status "INFO" "  macOS: brew install ta-lib"
                print_status "INFO" "  Linux: apt-get install libta-lib-dev"
            fi
        fi
    fi
    
    print_status "INFO" "Dependency installation complete"
}

# Function to validate installation
validate_installation() {
    print_status "INFO" "Validating installation..."
    
    # Activate virtual environment if it exists
    local venv_dir="${SCRIPT_DIR}/venv"
    if [[ -d "$venv_dir" ]]; then
        source "${venv_dir}/bin/activate"
        print_status "INFO" "Activated virtual environment for validation"
    fi
    
    # Test core imports
    local core_packages=("pandas" "numpy" "yfinance" "yaml" "jinja2")
    
    for package in "${core_packages[@]}"; do
        if python3 -c "import ${package}; print(f'✓ ${package}')" 2>/dev/null; then
            print_status "INFO" "✓ ${package} working"
        else
            print_status "ERROR" "✗ ${package} not working"
            return 1
        fi
    done
    
    print_status "INFO" "All core packages validated successfully"
}

# Function to set up directory structure
setup_directories() {
    print_status "INFO" "Setting up directory structure..."
    
    local dirs=("data/processed" "logs" "reports" "config")
    
    for dir in "${dirs[@]}"; do
        mkdir -p "${SCRIPT_DIR}/${dir}"
        print_status "DEBUG" "Created directory: ${dir}"
    done
    
    print_status "INFO" "Directory structure created"
}

# Function to make scripts executable
setup_permissions() {
    print_status "INFO" "Setting up script permissions..."
    
    local scripts=("run_pipeline.sh" "monitor.sh" "setup.sh")
    
    for script in "${scripts[@]}"; do
        local script_path="${SCRIPT_DIR}/${script}"
        if [[ -f "$script_path" ]]; then
            chmod +x "$script_path"
            print_status "DEBUG" "Made executable: ${script}"
        fi
    done
    
    # Make Python scripts executable
    find "${SCRIPT_DIR}/scripts" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true
    
    print_status "INFO" "Script permissions set"
}

# Function to create activation script
create_activation_script() {
    print_status "INFO" "Creating activation script..."
    
    local activate_script="${SCRIPT_DIR}/activate_env.sh"
    
    cat > "$activate_script" << 'EOF'
#!/bin/zsh
# Activation script for Market Data Pipeline (venv version)

if [[ -n "${ZSH_VERSION}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

VENV_DIR="${SCRIPT_DIR}/venv"

if [[ -d "$VENV_DIR" ]]; then
    source "${VENV_DIR}/bin/activate"
    echo "✓ Virtual environment activated"
    echo "Pipeline directory: ${SCRIPT_DIR}"
    echo "Python: $(which python)"
    echo ""
    echo "Quick start commands:"
    echo "  ./run_pipeline.sh health    # Check system health"
    echo "  ./run_pipeline.sh full      # Run full pipeline"
    echo "  ./monitor.sh               # Run monitoring checks"
    echo ""
else
    echo "Virtual environment not found at: ${VENV_DIR}"
    echo "Run ./setup.sh to set it up"
fi
EOF
    
    chmod +x "$activate_script"
    print_status "INFO" "Created activation script: activate_env.sh"
}

# Function to test pipeline
test_pipeline() {
    print_status "INFO" "Testing pipeline setup..."
    
    # Activate virtual environment if it exists
    local venv_dir="${SCRIPT_DIR}/venv"
    if [[ -d "$venv_dir" ]]; then
        source "${venv_dir}/bin/activate"
    fi
    
    # Run health check
    if "${SCRIPT_DIR}/run_pipeline.sh" health; then
        print_status "INFO" "Pipeline health check passed"
    else
        print_status "WARN" "Pipeline health check failed"
        return 1
    fi
    
    print_status "INFO" "Pipeline test complete"
}

# Function to show completion message
show_completion_message() {
    print_status "INFO" "Setup completed successfully!"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}Market Data Pipeline is ready!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo -e "${BLUE}Quick Start:${NC}"
    echo "  1. Activate environment: source ./activate_env.sh"
    echo "  2. Run health check:     ./run_pipeline.sh health"
    echo "  3. Run full pipeline:    ./run_pipeline.sh full"
    echo "  4. Monitor system:       ./monitor.sh"
    echo
    echo -e "${BLUE}Pipeline Structure:${NC}"
    echo "  📁 config/         - Configuration files"
    echo "  📁 scripts/        - Python scripts"  
    echo "  📁 data/           - Downloaded market data"
    echo "  📁 data/processed/ - Processed data with indicators"
    echo "  📁 reports/        - Generated HTML reports"
    echo "  📁 logs/           - System and operation logs"
    echo
    echo -e "${BLUE}Main Commands:${NC}"
    echo "  ./run_pipeline.sh full                    # Complete pipeline"
    echo "  ./run_pipeline.sh --symbols AAPL,GOOGL    # Specific symbols"
    echo "  ./run_pipeline.sh report --open           # Generate & open report"
    echo "  ./monitor.sh                              # System monitoring"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  • Edit config/symbols.yaml to add your preferred stocks"
    echo "  • Set up a cron job for automated runs"
    echo "  • Configure email notifications in monitor.sh"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Market Data Pipeline Setup Script

OPTIONS:
    --venv         Create virtual environment
    --deps         Install dependencies only
    --test         Test installation only
    --full         Full setup (default)
    --help, -h     Show this help

EXAMPLES:
    $0             # Full setup
    $0 --venv      # Create virtual environment only
    $0 --deps      # Install dependencies only
    $0 --test      # Test existing installation

EOF
}

# Main function
main() {
    local setup_type="full"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --venv)
                setup_type="venv"
                shift
                ;;
            --deps)
                setup_type="deps"
                shift
                ;;
            --test)
                setup_type="test"
                shift
                ;;
            --full)
                setup_type="full"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_status "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Welcome message
    echo -e "${BLUE}Market Data Pipeline Setup${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    case "$setup_type" in
        "venv")
            check_python
            setup_virtual_env
            ;;
        "deps")
            check_python
            install_dependencies
            validate_installation
            ;;
        "test")
            validate_installation
            test_pipeline
            ;;
        "full")
            check_python
            setup_directories
            setup_virtual_env
            install_dependencies
            validate_installation
            setup_permissions
            create_activation_script
            test_pipeline
            show_completion_message
            ;;
    esac
    
    print_status "INFO" "Setup operation '${setup_type}' completed"
}

# Run main function with all arguments
main "$@"
