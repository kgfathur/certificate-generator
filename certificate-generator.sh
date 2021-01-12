#!/bin/bash

workdir=$PWD
outdir="$workdir/certs"

rsa_bit=4096
ca_key="ca-key.pem"
ca_cert="ca.pem"
server_key="server-key.pem"
server_cert="server-cert.pem"
server_csr="server.csr"
client_key="key.pem"
client_cert="cert.pem"
host_name=$(hostname -f)
host_ip=$(hostname -I | sed 's/ $//g')
default=Yes

#####################################################################
# Print warning message.

function warning()
{
    echo "$*" >&2
}

#####################################################################
# Print error message and exit.

function error()
{
    echo "$*" >&2
    exit 1
}


#####################################################################
# Ask yesno question.
#
# Usage: yesno OPTIONS QUESTION
#
#   Options:
#     --timeout N    Timeout if no input seen in N seconds.
#     --default ANS  Use ANS as the default answer on timeout or
#                    if an empty answer is provided.
#
# Exit status is the answer.

function yesno()
{
    local ans
    local ok=0
    local timeout=0
    local default
    local t

    while [[ "$1" ]]
    do
        case "$1" in
        --default)
            shift
            default=$1
            if [[ ! "$default" ]]; then error "Missing default value"; fi
            t=$(tr '[:upper:]' '[:lower:]' <<<$default)

            if [[ "$t" != 'y'  &&  "$t" != 'yes'  &&  "$t" != 'n'  &&  "$t" != 'no' ]]; then
                error "Illegal default answer: $default"
            fi
            default=$t
            shift
            ;;

        --timeout)
            shift
            timeout=$1
            if [[ ! "$timeout" ]]; then error "Missing timeout value"; fi
            if [[ ! "$timeout" =~ ^[0-9][0-9]*$ ]]; then error "Illegal timeout value: $timeout"; fi
            shift
            ;;

        -*)
            error "Unrecognized option: $1"
            ;;

        *)
            break
            ;;
        esac
    done

    if [[ $timeout -ne 0  &&  ! "$default" ]]; then
        error "Non-zero timeout requires a default answer"
    fi

    if [[ ! "$*" ]]; then error "Missing question"; fi

    while [[ $ok -eq 0 ]]
    do
        if [[ $timeout -ne 0 ]]; then
            if ! read -t $timeout -p "$*" ans; then
                ans=$default
            else
                # Turn off timeout if answer entered.
                timeout=0
                if [[ ! "$ans" ]]; then ans=$default; fi
            fi
        else
            read -p "$*" ans
            if [[ ! "$ans" ]]; then
                ans=$default
            else
                ans=$(tr '[:upper:]' '[:lower:]' <<<$ans)
            fi 
        fi

        if [[ "$ans" == 'y'  ||  "$ans" == 'yes'  ||  "$ans" == 'n'  ||  "$ans" == 'no' ]]; then
            ok=1
        fi

        if [[ $ok -eq 0 ]]; then warning "Valid answers are: Y|YES|Yes|yes|y N|NO|No|no|n"; fi
    done
    [[ "$ans" = "y" || "$ans" == "yes" ]]
}

set_outdir() {
    echo "Current Working Directory: ${workdir}"
    echo "Certificate Output Directory: ${outdir}"
    
    if [ ! -d $outdir ]; then
        echo "Directory '$outdir'not exist!"
        echo "Creating... '$outdir'"
        mkdir -p $outdir
    fi
    ca_key="${outdir}/ca-key.pem"
    ca_cert="${outdir}/ca.pem"
    server_key="${outdir}/server-key.pem"
    server_cert="${outdir}/server-cert.pem"
    server_csr="${outdir}/server.csr"
    server_extfile="${outdir}/extfile.cnf"
    client_key="${outdir}/key.pem"
    client_cert="${outdir}/cert.pem"
    client_csr="${outdir}/client.csr"
    client_extfile="${outdir}/extfile-client.cnf"
}

get_params() {
    echo "Default Configuration:"
    echo -e "   1) RSA \t\t\t= ${rsa_bit}-bit"
	echo -e "   2) CA key \t\t\t= ${ca_key}"
	echo -e "   3) CA Certificate \t\t= ${ca_cert}"
	echo -e "   4) Server Key \t\t= ${server_key}"
	echo -e "   5) Server Certicifate \t= ${server_cert}"
	echo -e "   6) Server Key \t\t= ${server_key}"
	echo -e "   7) Server Certicifate \t= ${server_cert}"
	echo -e "   8) Hostname \t\t\t= ${host_name}"
	echo -e "   9) Host IP Address \t\t= ${host_ip}"
    # until [[ -n "$get_public_ip" || -n "$public_ip" ]]; do
	# 	echo "Invalid input."
	# 	read -p "Public IPv4 address / hostname: " public_ip
	# done
}

certificate_check() {
    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Check CA Private Key (RSA)"
    openssl rsa -in $ca_key -check
    sleep 3

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Check CA Certificate"
    openssl x509 -in $ca_cert -text -noout
    echo ""
}

certificate_generate() {
    host_ip=$(echo "IP:$host_ip" | sed -e 's/ /,IP:/g')
    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Generate CA Private Key"
    if [ -f $ca_key ]; then
        if yesno --default yes "$ca_key Already exist, overwrite? (Yes|No) [$default] "; then
            echo "openssl genrsa -aes256 -out $ca_key $rsa_bit"
            openssl genrsa -aes256 -out $ca_key $rsa_bit
        else
            echo "Using existing: $ca_key"
        fi
    else
        echo "openssl genrsa -aes256 -out $ca_key $rsa_bit"
        openssl genrsa -aes256 -out $ca_key $rsa_bit
    fi

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Generate CA Certificate"
    if [ -f $ca_cert ]; then
        if yesno --default yes "$ca_cert Already exist, overwrite? (Yes|No) [$default] "; then
            echo "openssl req -new -x509 -days 365 -key $ca_key -sha256 -out $ca_cert"
            openssl req -new -x509 -days 365 -key $ca_key -sha256 -out $ca_cert
        else
            echo "Using existing: $ca_cert"
        fi
    else
        echo "openssl req -new -x509 -days 365 -key $ca_key -sha256 -out $ca_cert"
        openssl req -new -x509 -days 365 -key $ca_key -sha256 -out $ca_cert
    fi
    

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Generate Server Key"
    if [ -f $server_key ]; then
        if yesno --default yes "$server_key Already exist, overwrite? (Yes|No) [$default] "; then
            echo "openssl genrsa -out $server_key $rsa_bit"
            openssl genrsa -out $server_key $rsa_bit
        else
            echo "Using existing: $server_key"
        fi
    else
        echo "openssl genrsa -out $server_key $rsa_bit"
        openssl genrsa -out $server_key $rsa_bit
    fi
    

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Certificate Signing Request (CSR)"
    if [ -f $server_csr ]; then
        if yesno --default yes "$server_csr Already exist, overwrite? (Yes|No) [$default] "; then
            echo "openssl req -subj "/CN=$host_name " -sha256 -new -key $server_key -out $server_csr"
            openssl req -subj "/CN=$host_name " -sha256 -new -key $server_key -out $server_csr            
        else
            echo "Using existing: $server_csr"
        fi
    else
        echo "openssl req -subj "/CN=$host_name " -sha256 -new -key $server_key -out $server_csr"
        openssl req -subj "/CN=$host_name " -sha256 -new -key $server_key -out $server_csr
    fi
    

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Set DNS and IP Address"
    if [ -f $server_extfile ]; then
        if yesno --default yes "$server_extfile Already exist, overwrite? (Yes|No) [$default] "; then
            rm -rf $server_extfile
            echo "echo subjectAltName = DNS:$host_name,$host_ip,IP:127.0.0.1 >> $server_extfile"
            echo "echo extendedKeyUsage = serverAuth >> $server_extfile"
            echo subjectAltName = DNS:$host_name,$host_ip,IP:127.0.0.1 >> $server_extfile
            echo extendedKeyUsage = serverAuth >> $server_extfile
            cat $server_extfile
        else
            echo "Using existing: $server_extfile"
        fi
    else
        echo "echo subjectAltName = DNS:$host_name,$host_ip,IP:127.0.0.1 >> $server_extfile"
        echo "echo extendedKeyUsage = serverAuth >> $server_extfile"
        echo subjectAltName = DNS:$host_name,$host_ip,IP:127.0.0.1 >> $server_extfile
        echo extendedKeyUsage = serverAuth >> $server_extfile
        cat $server_extfile
    fi

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Generate the Signed Certificate:"
    if [ -f $server_cert ]; then
        if yesno --default yes "$server_cert Already exist, overwrite? (Yes|No) [$default] "; then
            echo "openssl x509 -req -days 365 -sha256 -in $server_csr -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $server_cert -extfile $server_extfile"
            openssl x509 -req -days 365 -sha256 -in $server_csr -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $server_cert -extfile $server_extfile
        else
            echo "Using existing: $server_cert"
        fi
    else
        echo "openssl x509 -req -days 365 -sha256 -in $server_csr -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $server_cert -extfile $server_extfile"
        openssl x509 -req -days 365 -sha256 -in $server_csr -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $server_cert -extfile $server_extfile
    fi

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Create a Client Key"
    if [ -f $client_key ]; then
        if yesno --default yes "$client_key Already exist, overwrite? (Yes|No) [$default] "; then
            echo "openssl genrsa -out $client_key $rsa_bit"
            openssl genrsa -out $client_key $rsa_bit
        else
            echo "Using existing: $client_key"
        fi
    else
        echo "openssl genrsa -out $client_key $rsa_bit"
        openssl genrsa -out $client_key $rsa_bit
    fi

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Create Client Certificate Signing Request"
    if [ -f $client_csr ]; then
        if yesno --default yes "$client_csr Already exist, overwrite? (Yes|No) [$default] "; then
            echo "openssl req -subj '/CN=client' -new -key $client_key -out $client_csr"
            openssl req -subj '/CN=client' -new -key $client_key -out $client_csr
        else
            echo "Using existing: $client_csr"
        fi
    else
        echo "openssl req -subj '/CN=client' -new -key $client_key -out $client_csr"
        openssl req -subj '/CN=client' -new -key $client_key -out $client_csr
    fi

    echo ""
    echo "- - - - - - - - - - - - - - -"
    echo "Client Extension Config"
    if [ -f $client_extfile ]; then
        if yesno --default yes "$client_extfile Already exist, overwrite? (Yes|No) [$default] "; then
            rm -rf $client_extfile
            echo "echo extendedKeyUsage = clientAuth > $client_extfile"
            echo "openssl x509 -req -days 365 -sha256 -in $client_csr -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $client_cert -extfile $client_extfile"
            echo extendedKeyUsage = clientAuth > $client_extfile
            openssl x509 -req -days 365 -sha256 -in $client_csr -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $client_cert -extfile $client_extfile
        else
            echo "Using existing: $client_extfile"
        fi
    else
        echo "echo extendedKeyUsage = clientAuth > $client_extfile"
        echo "openssl x509 -req -days 365 -sha256 -in $client_csr -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $client_cert -extfile $client_extfile"
        echo extendedKeyUsage = clientAuth > $client_extfile
        openssl x509 -req -days 365 -sha256 -in $client_csr -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $client_cert -extfile $client_extfile
    fi
}

set_outdir
get_params
certificate_generate

if yesno --default No "Check generated certificate? This will print CA Private Key! (Yes|No) "; then
    certificate_check
fi