#!/bin/bash
## # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                 CERTIFICATE GENERATOR HELPER
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                     Build for lazy guys,
#                 or help people to understand
#            the process of generating cerificate
#
#                   for more useless things,
#                  visit: github.com/kgfathur
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Actually this based on server client auth for Docker Daemon
# However this can be used for other purpose 
# https://docs.docker.com/engine/security/protect-access/
# 
# Reference:
# - https://stackoverflow.com/questions/21141215/creating-a-p12-file
# - https://gist.github.com/Eng-Fouad/6cdc8263068700ade87e4e3bf459a988
# - https://devcenter.heroku.com/articles/ssl-certificate-self
# - https://www.phildev.net/ssl/opensslconf.html
# - http://www.littlebigextra.com/how-to-add-subject-alt-names-or-multiple-domains-in-a-key-store-and-self-signed-certificate/
# - https://rkakodker.medium.com/how-to-simple-way-of-generating-wildcard-san-ssl-csrs-for-product-managers-8c25d715d86f
#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# command this clear screen and filling scrollback
# printf "\033[H"
# this one more flexible, wont lost stdout history
printf "\033[2J" && printf "\033[H"
# Reference: https://stackoverflow.com/questions/5367068/clear-a-terminal-screen-for-real
# Read more VT100 terminal escape codes:
# https://vt100.net/docs/vt510-rm/chapter4.html
# https://www2.ccs.neu.edu/research/gpc/MSim/vona/terminal/vtansi.htm

echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
echo "                 CERTIFICATE GENERATOR HELPER"
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "                     Build for lazy guys,"
echo "                 or help people to understand"
echo "            the process of generating cerificate"
echo ""
echo "                   for more useless things,"
echo "                  visit: github.com/kgfathur"
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"

workdir=$PWD
outdir="$workdir/certs"
default_config_dir="$workdir/config"
default_config_file="ssl.conf"
default_config_file_fp="$default_config_dir/${default_config_file}"

default_master_pass=Yes
default_days=365
default_rsa_bit=4096
out_prefix_default=""
default_delimiter="-"

ca_key="ca.key"
ca_cert="ca.crt"
server_key="server.key"
server_csr="server.csr"
server_cert="server.crt"

pkcs12_cert_create=No
pkcs12_name="server-pkcs"
pkcs12_cert="server.p12"

default_client_cn="client"
client_key="client.key"
client_csr="client.csr"
client_cert="client.crt"
client_extfile="client-extfile.cnf"
client_cert_create=No
default=Yes

print_params() {
    if [[ -z "$out_prefix" ]]; then
        delimiter=''
    else
        [[ -z "$default_delimiter" ]] && default_delimiter='-'
        delimiter=$default_delimiter
    fi

    out_ca_key="${outdir}/${out_prefix}${delimiter}${ca_key}"
    out_ca_cert="${outdir}/${out_prefix}${delimiter}${ca_cert}"
    out_server_key="${outdir}/${out_prefix}${delimiter}${server_key}"
    out_server_csr="${outdir}/${out_prefix}${delimiter}${server_csr}"
    out_server_cert="${outdir}/${out_prefix}${delimiter}${server_cert}"
    
    if [ "$pkcs12_create_is" == "True" ]; then
        out_pkcs12_cert="${outdir}/${out_prefix}${delimiter}${pkcs12_cert}"
    fi

    if [ "$client_create_is" == "True" ]; then
        out_client_key="${outdir}/${out_prefix}${delimiter}${client_key}"
        out_client_csr="${outdir}/${out_prefix}${delimiter}${client_csr}"
        out_client_cert="${outdir}/${out_prefix}${delimiter}${client_cert}"
        out_client_extfile="${outdir}/${out_prefix}${delimiter}${client_extfile}"
    fi
    

    echo "$1 Configuration:"
	echo -e "   1) Config File \t\t= ${config_file_fp}"
	echo -e "   2) Use Master Pass Phrase \t= ${master_pass}"
    echo -e "   3) RSA \t\t\t= ${rsa_bit}-bits"
    echo -e "   4) Days \t\t\t= ${days} days"
	echo -e "   5) Output Prefix \t\t= ${out_prefix}"
	echo -e "   6) CA Private key \t\t= ${out_ca_key}"
	echo -e "   7) CA Certificate \t\t= ${out_ca_cert}"
	echo -e "   8) Server Key \t\t= ${out_server_key}"
	echo -e "   9) Server CSR \t\t= ${out_server_csr}"
	echo -e "  10) Server Certicifate \t= ${out_server_cert}"
	echo -e "  11) Generte PKCS#12 \t\t= ${pkcs12_cert_create}"
	echo -e "  12) PKCS#12 Name \t\t= ${pkcs12_name}"
	echo -e "  13) PKCS#12 Certicifate \t= ${out_pkcs12_cert}"
	echo -e "  14) Generate Client Cert. \t= ${client_cert_create}"
	echo -e "  15) Client Common Name \t= ${client_cn}"
	echo -e "  16) Client Key \t\t= ${out_client_key}"
	echo -e "  17) Client CSR \t\t= ${out_client_csr}"
	echo -e "  18) Client Certicifate \t= ${out_client_cert}"
}

set_pass() {
    unset pass_phrase
    prompt="Enter Pass Phrase: "
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]]
        then
            break
        fi
        prompt='*'
        pass_phrase+="$char"
    done
    [[ -z "$pass_phrase" ]] && master_pass=$default_master_pass
    echo ""
}

set_params() {

    echo "Current Working Directory:"
    echo "  ${workdir}"
    echo "Certificate Output Directory:"
    echo "  ${outdir}"
    
    if [ ! -d $outdir ]; then
        echo "Directory '$outdir'not exist!"
        echo "Creating... '$outdir'"
        mkdir -p $outdir
    fi
    
    client_cn=$default_client_cn
    master_pass=$default_master_pass
    out_prefix=$out_prefix_default
    config_file_fp=$default_config_file_fp
    rsa_bit=$default_rsa_bit
    days=$default_days
    
    [[ ! -z "$out_prefix_default" ]] && out_prefix=$out_prefix_default

    print_params 'Default'

    echo ""
    default_answer=$master_pass
    if yesno --default $default_answer "Set Master Password? (Yes|No) [$default_answer] "; then
        echo "Use Master Pass Phrase set to: $master_pass"
        master_pass_is=True
    else
        master_pass=No
        master_pass_is=False
        echo "Use Master Pass Phrase set to: $master_pass"
    fi
    ans=$(tr '[:upper:]' '[:lower:]' <<<$master_pass)
    if [[ "$ans" == 'y'  ||  "$ans" == 'yes'  ||  "$ans" == 'n'  ||  "$ans" == 'no' ]]; then
        if [[ "$ans" = "y" || "$ans" == "yes" ]]; then
            set_pass
        fi
    fi

    echo ""
    default_answer=No
    if yesno --default $default_answer "Set RSA bits? (Yes|No) [$default_answer] "; then
		read -p "RSA bits [$default_rsa_bit]: " rsa_bit
		[[ -z "$rsa_bit" ]] && rsa_bit=$default_rsa_bit
        echo "RSA bits set to: $rsa_bit"
    else
        rsa_bit=$default_rsa_bit
        echo "Using default RSA bits: $rsa_bit bits"
    fi

    echo ""
    default_answer=No
    if yesno --default $default_answer "Set Days of Validity? (Yes|No) [$default_answer] "; then
		read -p "Days [$default_days]: " days
		[[ -z "$days" ]] && days=$default_days
        echo "Days set to: $days days"
    else
        days=$default_days
        echo "Using default Days: $days days"
    fi

    echo ""
    default_answer=Yes
    if yesno --default $default_answer "Set Prefix for Output files? (Yes|No) [$default_answer] "; then
		read -p "Output Prefix [$out_prefix]: " out_prefix
		[[ -z "$out_prefix" ]] && out_prefix=$out_prefix_default
        echo "Output Prefix set to: $out_prefix"
    else
        out_prefix=$out_prefix
        echo "Using default Output Prefix: $out_prefix"
    fi

    echo ""
    default_answer=$pkcs12_cert_create
    if yesno --default $default_answer "Create PKCS#12 Certificate? (Yes|No) [$default_answer] "; then
        pkcs12_cert_create=Yes
        pkcs12_create_is=True
    else
        pkcs12_cert_create=No
        pkcs12_create_is=False
    fi

    if [ "$pkcs12_create_is" == "True" ]; then
        default_answer=No
        [[ ! -z "$out_prefix" ]] && pkcs12_name="$out_prefix-pkcs"
        echo "Default PKCS#12 Name: ${pkcs12_name}"
        if yesno --default $default_answer "Set PKCS#12 Name? (Yes|No) [$default_answer] "; then
            read -p "PKCS#12 Name [$pkcs12_name]: " pkcs12_name
            [[ -z "$pkcs12_name" ]] && pkcs12_name=$client_cn
        else
            pkcs12_name=$pkcs12_name
        fi
    else
        pkcs12_name=""
        out_pkcs12_cert=""
    fi
    echo "Set Create PKCS#12 to: $pkcs12_cert_create"
    echo "Set PKCS#12 Name to: $pkcs12_name"
    
    echo ""
    default_answer=$client_cert_create
    if yesno --default $default_answer "Create Client Certificate? (Yes|No) [$default_answer] "; then
        client_cert_create=Yes
        client_create_is=True
    else
        client_cert_create=No
        client_create_is=False
    fi

    if [ "$client_create_is" == "True" ]; then
        default_answer=No
        [[ ! -z "$out_prefix" ]] && client_cn=$out_prefix
        echo "Default Client Common Name: ${client_cn}"
        if yesno --default $default_answer "Set Client Common Name? (Yes|No) [$default_answer] "; then
            read -p "Client Common Name [$client_cn]: " client_cn
            [[ -z "$client_cn" ]] && client_cn=$default_client_cn
        else
            client_cn=$client_cn
        fi
    else
        client_cn=""        
        out_client_key=""
        out_client_csr=""
        out_client_cert=""
        out_client_extfile=""
    fi
    echo "Set Create Client Certificate to: $client_cert_create"
    echo "Set Client Common Name to: $client_cn"
    
    echo ""
    default_answer=No
    echo "Current Config Dir:"
    echo "  '${default_config_dir}'"
    if yesno --default $default_answer "Change Config dir? (Yes|No) [$default_answer] "; then
		read -p "Config dir [$default_config_dir]: " config_dir
		[[ -z "$config_dir" ]] && config_dir=$default_config_dir
        echo "Config dir set to: $config_dir"
    else
        config_dir=$default_config_dir
        echo "Using Config dir: $config_dir"
    fi

    echo ""
    default_answer=No
    echo "Current Config File:"
    echo "  '${config_dir}/{${default_config_file}}'"
    if yesno --default $default_answer "Change Config file? (Yes|No) [$default_answer] "; then
		read -p "Config file [$default_config_file]: " config_file
		[[ -z "$config_file" ]] && config_file=$default_config_file
        echo "Config file set to: $config_file"
        config_file_fp=${config_dir}/${config_file}
        echo "Config file full path: $config_file_fp"
    else
        config_file=$default_config_file
        echo "Using Config file: $config_file"
        config_file_fp=${config_dir}/${config_file}
        echo "Config file full path: $config_file_fp"
    fi
}

get_config() {
    if [ ! -d $config_dir ]; then
        echo "config_file: cannot access '$config_file_fp': No such file or directory"
        echo "Creating... '$config_dir' for future use"
        mkdir -p $config_dir
    fi

    if [ ! -f $config_file_fp ]; then
        echo "config_file: cannot access '$config_file_fp': No such file or directory"
        echo "Creating empty config file... '$config_file_fp'"
        touch $config_file_fp
    else
        echo ""
        echo "Loading config file..."
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo "# - - - - - - - - - START OF CONFIG FILE  - - - - - - - - - - -"
        cat $config_file_fp
        echo ""
        echo "# - - - - - - - - - END OF CONFIG FILE  - - - - - - - - - - - -"
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo ""
    fi
    
    print_params 'Running'
    echo ""
    default_answer=Yes
    if yesno --default $default_answer "Continue? (Yes|No) [$default_answer] "; then
        echo "Processing your request..."
    else
        echo "Aborting..."
        exit
    fi
    echo ""
}

certificate_check() {

    local ans
    
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                        Check Server CSR"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    openssl req -in $out_server_csr -noout -text
    echo ""
    sleep 1

    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                    Check Server CA Certificate"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    openssl x509 -in $out_ca_cert -text -noout
    echo ""
    sleep 1

    ans=$(tr '[:upper:]' '[:lower:]' <<<$client_cert_create)
    if [[ "$ans" == 'y'  ||  "$ans" == 'yes'  ||  "$ans" == 'n'  ||  "$ans" == 'no' ]]; then
        if [[ "$ans" = "y" || "$ans" == "yes" ]]; then
        
            echo ""
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            echo "                       Check Client CSR"
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            openssl req -in $out_client_csr -noout -text
            echo ""
            sleep 1

            echo ""
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            echo "                   Check Client Certificate"
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            openssl x509 -in $out_client_cert -text -noout
            echo ""
        fi
    fi
    
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                       S U M M A R Y"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo ""
    print_params 'Summary'
    echo ""
}

certificate_generate() {
    echo ""
    echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
    echo "             START OF GENERATING CERTIFICATE PROCES"
    echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                 Generate CA Private Key"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    if [ "$master_pass_is" == "True" ]; then
        cmd="openssl genrsa -aes256 -passout pass:$pass_phrase -out $out_ca_key $rsa_bit"
    else
        cmd="openssl genrsa -aes256 -out $out_ca_key $rsa_bit"
    fi
    if [ -f $out_ca_key ]; then
        default_answer=Yes
        echo "CA Private Key Already Exist:"
        echo "  '${out_ca_key}}'"
        if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
            echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-out\)/pass:**** -out/g'
            eval "$cmd"
        else
            echo "Using existing: $out_ca_key"
        fi
    else
        echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-out\)/pass:**** -out/g'
        eval "$cmd"
    fi

    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                Generate CA Certificate"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    if [ "$master_pass_is" == "True" ]; then
        cmd="openssl req -new -x509 -days $days -passin pass:$pass_phrase -key $out_ca_key -sha256 -out $out_ca_cert -config $config_file_fp"
    else
        cmd="openssl req -new -x509 -days $days -key $out_ca_key -sha256 -out $out_ca_cert -config $config_file_fp"
    fi
    if [ -f $out_ca_cert ]; then
        default_answer=Yes
        echo "CA Certificate Already Exist:"
        echo "  '${out_ca_cert}'"
        if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
            echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-key\)/pass:**** -key/g'
            eval "$cmd"
        else
            echo "Using existing: $out_ca_cert"
        fi
    else
        echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-key\)/pass:**** -key/g'
        eval "$cmd"
    fi
    
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                Generate Server Private Key"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    if [ "$master_pass_is" == "True" ]; then
        cmd="openssl genrsa -passout pass:$pass_phrase -out $out_server_key $rsa_bit"
    else
        cmd="openssl genrsa -out $out_server_key $rsa_bit"
    fi
    if [ -f $out_server_key ]; then
        default_answer=Yes
        echo "Server Private Key Already Exist:"
        echo "  '${out_server_key}'"
        if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
            echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-out\)/pass:**** -out/g'
            eval "$cmd"
        else
            echo "Using existing: $out_server_key"
        fi
    else
        echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-out\)/pass:**** -out/g'
        eval "$cmd"
    fi

    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "           Generate Certificate Signing Request (CSR)"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    cmd="openssl req -sha256 -new -key $out_server_key -config $config_file_fp -out $out_server_csr"
    if [ -f $out_server_csr ]; then
        default_answer=Yes
        echo "Server CSR Already Exist:"
        echo "  '${out_server_csr}'"
        if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
            echo "$cmd"
            eval "$cmd"
        else
            echo "Using existing: $out_server_csr"
        fi
    else
        echo "$cmd"
        eval "$cmd"
    fi

    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "           Generate the Server Signed Certificate:"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    if [ "$master_pass_is" == "True" ]; then
        cmd="openssl x509 -req -sha256 -days $days -passin pass:$pass_phrase -in $out_server_csr -CA $out_ca_cert -CAkey $out_ca_key -CAcreateserial -signkey $out_server_key -out $out_server_cert"
    else
        cmd="openssl x509 -req -sha256 -days $days -in $out_server_csr -CA $out_ca_cert -CAkey $out_ca_key -CAcreateserial -signkey $out_server_key -out $out_server_cert"
    fi
    if [ -f $out_server_cert ]; then
        default_answer=Yes
        echo "Server Signed Certificate Already Exist:"
        echo "  '${out_server_cert}'"
        if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
            echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-in\)/pass:**** -in/g'
            eval "$cmd"
        else
            echo "Using existing: $out_server_cert"
        fi
    else
        echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-in\)/pass:**** -in/g'
        eval "$cmd"
    fi

    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                    PKCS#12 SSL certificate"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    if [ "$master_pass_is" == "True" ]; then
        cmd="openssl pkcs12 -export -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -export -passout pass:$pass_phrase -in $out_server_cert -inkey $out_server_key -name $pkcs12_name -out $out_pkcs12_cert"
    else
        cmd="openssl pkcs12 -export -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -export -in $out_server_cert -inkey $out_server_key -name $pkcs12_name -out $out_pkcs12_cert"
    fi
    echo "Create PKCS#12: $pkcs12_cert_create"
    if [ "$pkcs12_create_is" == "True" ]; then
        echo "PKCS#12 Name: $pkcs12_name"
        echo ""
        
        if [ -f $out_pkcs12_cert ]; then
            default_answer=Yes
            echo "PKCS#12 Certificate Already Exist:"
            echo "  '${out_pkcs12_cert}'"
            if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
                echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-in\)/pass:**** -in/g'
                eval "$cmd"
            else
                echo "Using existing: $out_server_cert"
            fi
        else
            echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-in\)/pass:**** -in/g'
            eval "$cmd"
        fi

    fi
    
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                 Client SSL Auth Certificate"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "Create Client Certificate: $client_cert_create"
    if [ "$client_create_is" == "True" ]; then
        echo "Client Common Name: $client_cn"

        echo ""
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo "                   Create Client Private Key"
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        if [ "$master_pass_is" == "True" ]; then
            cmd="openssl genrsa -passout pass:$pass_phrase -out $out_client_key $rsa_bit"
        else
            cmd="openssl genrsa -passout pass:$pass_phrase -out $out_client_key $rsa_bit"
        fi
        if [ -f $out_client_key ]; then
            default_answer=Yes
            echo "Client Private Key Already Exist:"
            echo "  '${out_client_key}'"
            if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
                echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-out\)/pass:**** -out/g'
                eval "$cmd"
            else
                echo "Using existing: $out_client_key"
            fi
        else
            echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-out\)/pass:**** -out/g'
            eval "$cmd"
        fi

        echo ""
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo "        Create Client Certificate Signing Request (CSR)"
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        cmd="openssl req -subj "/CN=$client_cn" -new -key $out_client_key -out $out_client_csr"
        if [ -f $out_client_csr ]; then
            default_answer=Yes
            echo "Client CSR Already Exist:"
            echo "  '${out_client_csr}'"
            if yesno --default $default_answer "Already exist, overwrite? (Yes|No) [$default_answer] "; then
                echo "$cmd"
                eval "$cmd"
            else
                echo "Using existing: $out_client_csr"
            fi
        else
            echo "$cmd"
            eval "$cmd"
        fi
        
        echo ""
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo "              Generate Client Signed Certificate"
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        if [ "$master_pass_is" == "True" ]; then
            cmd1="echo 'extendedKeyUsage = clientAuth' > $out_client_extfile"
            cmd2="openssl x509 -req -days $days -sha256 -in $out_client_csr -passin pass:$pass_phrase -CA $out_ca_cert -CAkey $out_ca_key -CAcreateserial -out $out_client_cert -extfile $out_client_extfile"
        else
            cmd1="echo 'extendedKeyUsage = clientAuth' > $out_client_extfile"
            cmd2="openssl x509 -req -days $days -sha256 -in $out_client_csr -CA $out_ca_cert -CAkey $out_ca_key -CAcreateserial -out $out_client_cert -extfile $out_client_extfile"
        fi
        if [ -f $out_client_csr ]; then
            default_answer=Yes
            echo "Client Signed Certificate Already Exist:"
            echo "  '${out_client_csr}'"
            if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
                rm -rf $out_client_extfile
                echo "$cmd1"
                echo "$cmd2" | sed -e 's/\(pass:.\{1,\}\s\-CA\)/pass:**** -CA/g'
                eval "$cmd1"
                eval "$cmd2"
            else
                echo "Using existing: $out_client_extfile"
            fi
        else
            echo "$cmd1"
            echo "$cmd2" | sed -e 's/\(pass:.\{1,\}\s\-CA\)/pass:**** -CA/g'
            eval "$cmd1"
            eval "$cmd2"
        fi
    fi
    
    echo ""
    echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
    echo "             END OF GENERATING CERTIFICATE PROCESS"
    echo "# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #"
    echo ""
}

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

set_params
get_config
certificate_generate

echo ""
echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
default_answer=Yes
if yesno --default $default_answer "Check generated certificate? (Yes|No) [$default_answer] "; then
    echo ""
    certificate_check
fi