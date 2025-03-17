#!/bin/bash

# Set strict bash options
set -euo pipefail

# Constants
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

readonly KEYSTORE_FILE_NAME="upload-keystore.jks"
readonly KEY_PROPERTIES_FILE_NAME="key.properties"
readonly KEYSTORE_FILE="./$KEYSTORE_FILE_NAME"
readonly KEY_PROPERTIES_FILE="./$KEY_PROPERTIES_FILE_NAME"

# Function to display usage
usage() {
    cat << EOF
Usage: $(basename "$0") --store-pass PASSWORD --key-pass PASSWORD --replace y/n [OPTIONS]

Required:
    --store-pass PASSWORD     Keystore password (min 6 chars)
    --key-pass PASSWORD      Key password (min 6 chars)
    --replace y/n           Replace existing keystore? (y/n)

Optional:
    --cn TEXT              Common Name
    --ou TEXT              Organizational Unit
    --org TEXT            Organization
    --location TEXT       City/Location
    --state TEXT         State/Province
    --country TEXT       Country Code
    --help               Show this help message

Example:
    $(basename "$0") --store-pass 123456 --key-pass 123456 --replace y \\
                     --cn "App Name" --ou "Unit" --org "Company" \\
                     --location "City" --state "State" --country "US"
EOF
    exit 1
}

# Function to log messages with color
log() {
    local level=$1
    local message=$2
    case "$level" in
        "error")   echo -e "${RED}Error: $message${NC}" >&2 ;;
        "warning") echo -e "${YELLOW}Warning: $message${NC}" ;;
        "success") echo -e "${GREEN}✅ $message${NC}" ;;
        *)         echo -e "$message" ;;
    esac
}

# Function to clean up on error
cleanup() {
    if [ -f "$KEYSTORE_FILE" ]; then
        rm -f "$KEYSTORE_FILE"
    fi
    if [ -f "$KEY_PROPERTIES_FILE" ]; then
        rm -f "$KEY_PROPERTIES_FILE"
    fi
    log "error" "Script failed. Cleaned up generated files."
    exit 1
}

# Set up error trap
trap cleanup ERR

# Parse named parameters
parse_params() {
    # Default values
    STOREPASS=""
    KEYPASS=""
    REPLACE=""
    CN=""
    OU=""
    O=""
    L=""
    ST=""
    C=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --store-pass)
                STOREPASS="$2"
                shift 2
                ;;
            --key-pass)
                KEYPASS="$2"
                shift 2
                ;;
            --replace)
                REPLACE="$2"
                shift 2
                ;;
            --cn)
                CN="$2"
                shift 2
                ;;
            --ou)
                OU="$2"
                shift 2
                ;;
            --org)
                O="$2"
                shift 2
                ;;
            --location)
                L="$2"
                shift 2
                ;;
            --state)
                ST="$2"
                shift 2
                ;;
            --country)
                C="$2"
                shift 2
                ;;
            --help)
                usage
                ;;
            -*|--*)
                log "error" "Unknown option $1"
                usage
                ;;
            *)
                log "error" "Invalid argument $1"
                usage
                ;;
        esac
    done

    # Validate required parameters
    validate_required_arg "store-pass" "$STOREPASS" 6
    validate_required_arg "key-pass" "$KEYPASS" 6
    validate_required_arg "replace" "$REPLACE" 1
}

# Function for validating required arguments
validate_required_arg() {
    local arg_name=$1
    local arg_value=$2
    local min_length=$3

    if [ -z "$arg_value" ]; then
        log "error" "--$arg_name is required"
        usage
    fi

    if [ ${#arg_value} -lt "$min_length" ]; then
        log "error" "--$arg_name must be at least $min_length characters"
        usage
    fi
}

# Function for validating optional arguments
validate_optional_arg() {
    local arg_name=$1
    local arg_value=$2

    if [ -z "$arg_value" ]; then
        log "warning" "--$arg_name is not provided. Using default/empty value."
    fi
}

# Main execution block
main() {
    # Parse command line arguments
    parse_params "$@"

    # Validate optional parameters
    validate_optional_arg "cn" "$CN"
    validate_optional_arg "ou" "$OU"
    validate_optional_arg "org" "$O"
    validate_optional_arg "location" "$L"
    validate_optional_arg "state" "$ST"
    validate_optional_arg "country" "$C"

    # Handle existing keystore
    if [ -f "$KEYSTORE_FILE" ]; then
        # Convert REPLACE to lowercase using tr instead
        case "$(echo "$REPLACE" | tr '[:upper:]' '[:lower:]')" in
            y|yes) 
                log "success" "Replacing the existing keystore..."
                rm -f "$KEYSTORE_FILE"
                ;;
            n|no)
                log "success" "Exiting without replacing the keystore."
                exit 0
                ;;
            *)
                log "error" "Invalid --replace argument. Use 'y' to replace or 'n' to exit."
                exit 1
                ;;
        esac
    fi

    # Display configuration
    log "success" "Configuration:"
    log "success" "store-pass: [hidden]"
    log "success" "key-pass: [hidden]"
    log "success" "cn: $CN"
    log "success" "ou: $OU"
    log "success" "org: $O"
    log "success" "location: $L"
    log "success" "state: $ST"
    log "success" "country: $C"

    # Generate keystore
    if ! keytool -genkey -v -keystore "$KEYSTORE_FILE" -keyalg RSA -keysize 2048 \
            -validity 10000 -alias app -dname "CN=$CN, OU=$OU, O=$O, L=$L, ST=$ST, C=$C" \
            -storepass "$STOREPASS" -keypass "$KEYPASS"; then
        log "error" "Failed to generate keystore."
        exit 1
    fi

    log "success" "Keystore generated successfully!"

    # Generate key.properties
    log "success" "Generating key.properties file..."
    cat <<EOL > "$KEY_PROPERTIES_FILE"
storePassword=$STOREPASS
keyPassword=$KEYPASS
keyAlias=app
storeFile=../app/${KEYSTORE_FILE_NAME}
EOL

    if [ -f "$KEY_PROPERTIES_FILE" ]; then
        log "success" "key.properties file created successfully!"
    else
        log "error" "Failed to create key.properties file."
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"
