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

## Existing object
default_ca_location="$outdir/ca"
default_cakey_existing="ca.key"
default_cacert_existing="ca.crt"
default_caconfig_file="ca.conf"

default_master_pass=Yes
default_days=365
default_rsa_bit=4096
out_prefix_default=""
default_delimiter="-"

# Choice
default=Yes
use_existing_ca=Yes
pkcs12_cert_create=No
client_cert_create=No

# Generated Output
ca_key="ca.key"
ca_cert="ca.crt"
server_key="server.key"
server_csr="server.csr"
server_cert="server.crt"

pkcs12_name="server-pkcs"
pkcs12_cert="server.p12"

default_client_cn="client"
client_key="client.key"
client_csr="client.csr"
client_cert="client.crt"
client_extfile="client-extfile.cnf"

clear_screen() {
    # command this clear screen and filling scrollback
    # printf "\033[H"
    # this one more flexible, wont lost stdout history
    printf "\033[2J" && printf "\033[H"
    # Reference: https://stackoverflow.com/questions/5367068/clear-a-terminal-screen-for-real
    # Read more VT100 terminal escape codes:
    # https://vt100.net/docs/vt510-rm/chapter4.html
    # https://www2.ccs.neu.edu/research/gpc/MSim/vona/terminal/vtansi.htm

}

print_params() {
    if [[ -z "$out_prefix" ]]; then
        delimiter=''
    else
        [[ -z "$default_delimiter" ]] && default_delimiter='-'
        delimiter=$default_delimiter
    fi

    [[ ! -z "$out_prefix" ]] && outdir="${outdir}/${out_prefix}"
    if [ ! -d $outdir ]; then
        echo "Output Directory:"
        echo "  '$outdir' not exist!"
        echo "Creating... '$outdir'"
        mkdir -p $outdir
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
    ans=$(tr '[:upper:]' '[:lower:]' <<<$use_existing_ca)
    if [ "$ans" == "yes" ]; then
        used_cakey="$cakey_existing_fp"
        used_cacert="$cacert_existing_fp"
        caconfig_file_fp=""
    else
        used_cakey="$out_ca_key"
        used_cacert="$out_ca_cert"
    fi
    
    echo ""
    echo "$1 Configuration:"
	echo -e "   1) Config File \t\t= ${config_file_fp}"
	echo -e "   2) Use Master Pass Phrase \t= ${master_pass}"
    echo -e "   3) RSA \t\t\t= ${rsa_bit}-bits"
    echo -e "   4) Days \t\t\t= ${days} days"
	echo -e "   5) Output Prefix \t\t= ${out_prefix}"
	echo -e "   6) Use Existing CA \t\t= ${use_existing_ca}"
	echo -e "   7) CA Config \t\t= ${caconfig_file_fp}"
	echo -e "   9) CA Private key \t\t= ${used_cakey}"
	echo -e "  10) CA Certificate \t\t= ${used_cacert}"
	echo -e "  11) Server Key \t\t= ${out_server_key}"
	echo -e "  12) Server CSR \t\t= ${out_server_csr}"
	echo -e "  13) Server Certicifate \t= ${out_server_cert}"
	echo -e "  14) Generte PKCS#12 \t\t= ${pkcs12_cert_create}"
	echo -e "  15) PKCS#12 Name \t\t= ${pkcs12_name}"
	echo -e "  16) PKCS#12 Certicifate \t= ${out_pkcs12_cert}"
	echo -e "  17) Generate Client Cert. \t= ${client_cert_create}"
	echo -e "  18) Client Common Name \t= ${client_cn}"
	echo -e "  19) Client Key \t\t= ${out_client_key}"
	echo -e "  20) Client CSR \t\t= ${out_client_csr}"
	echo -e "  21) Client Certicifate \t= ${out_client_cert}"
}

set_pass() {
    unset pass_phrase
    read -p "Enter Pass Phrase: " -r -s pass_phrase
    
    if [[ -z "$pass_phrase" ]]; then
        master_pass=No
        echo ""
        echo "Use password = Yes, But no password provide!"
    fi
    echo ""
}

set_params() {

    echo "Current Working Directory:"
    echo "  ${workdir}"
    echo "Certificate Output Directory:"
    echo "  ${outdir}"
    
    if [ ! -d $outdir ]; then
        echo "Default Output Directory:"
        echo "  '$outdir' not exist!"
        echo "Creating... '$outdir'"
        mkdir -p $outdir
    fi
    if [ ! -d $default_ca_location ]; then
        echo "Default CA Location Directory:"
        echo "  '$default_ca_location' not exist!"
        echo "Creating... '$default_ca_location'"
        mkdir -p $default_ca_location
        echo ""
    fi

    [[ -z "$config_dir" ]] && config_dir=$default_config_dir
    [[ -z "$config_file" ]] && config_file=$default_config_file
    [[ -z "$default_ca_location" ]] && default_ca_location=$outdir
    [[ -z "$ca_location" ]] && ca_location=$default_ca_location
    [[ -z "$cakey_existing" ]] && cakey_existing=$default_cakey_existing
    [[ -z "$cakey_existing_fp" ]] && cakey_existing_fp="${ca_location}/${cakey_existing}"
    [[ -z "$cacert_existing" ]] && cacert_existing=$default_cacert_existing
    [[ -z "$cacert_existing_fp" ]] && cacert_existing_fp="${ca_location}/${cacert_existing}"
    [[ -z "$caconfig_file" ]] && caconfig_file=$default_caconfig_file
    [[ -z "$caconfig_file_fp" ]] && caconfig_file_fp="${config_dir}/${caconfig_file}"
    
    
    if [ ! -d $config_dir ]; then
        echo "Default Config Directory:"
        echo "  '$config_dir' not exist!"
        echo "Creating... '$config_dir'"
        mkdir -p $config_dir
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
        master_pass_is=True
    else
        master_pass=No
        master_pass_is=False
    fi

    ans=$(tr '[:upper:]' '[:lower:]' <<<$master_pass)
    if [[ "$ans" == 'y'  ||  "$ans" == 'yes'  ||  "$ans" == 'n'  ||  "$ans" == 'no' ]]; then
        if [[ "$ans" = "y" || "$ans" == "yes" ]]; then
            set_pass
        fi
    fi
    echo "Use Master Pass Phrase set to: $master_pass"

    echo ""
    default_answer=Yes
    if yesno --default $default_answer "Set Common config name? (Yes|No) [$default_answer] "; then
		read -p "Common config name [$out_prefix]: " out_prefix
		[[ -z "$out_prefix" ]] && out_prefix=$out_prefix_default
        echo "Common config name set to: $out_prefix"
    else
        out_prefix=$out_prefix
        echo "Using default Common config name: $out_prefix"
    fi
    
    echo ""
    default_answer=No
    echo "Current Config Dir:"
    echo "  '${config_dir}'"
    if yesno --default $default_answer "Change Config dir? (Yes|No) [$default_answer] "; then
		read -p "Config dir [$config_dir]: " config_dir
		[[ -z "$config_dir" ]] && config_dir=$default_config_dir
        echo "Config dir set to: $config_dir"
    else
        config_dir=$config_dir
        echo "Using Config dir: $config_dir"
    fi

    echo ""
    default_answer=$use_existing_ca
    if yesno --default $default_answer "Use existing CA? (Yes|No) [$default_answer] "; then
        use_existing_ca="Yes"
        read -p "CA Location [$ca_location]: " ca_location
		[[ -z "$ca_location" ]] && ca_location=$default_ca_location
        echo "CA Location set to : $ca_location"

        echo "Existing CA Key:"
        echo "  '${ca_location}/{${cakey_existing}}'"
        until [[ -f "$cakey_existing_fp" ]]; do
            read -p "CA Key [$cakey_existing]: " cakey_existing
            [[ -z "$cakey_existing" ]] && cakey_existing=$default_cakey_existing
            cakey_existing_fp=${ca_location}/${cakey_existing}
            [[ ! -f $cakey_existing_fp ]] \
            && echo "cert-gen: cannot access '$cakey_existing_fp': No such file or directory"
		done
        echo "CA Key to: $cakey_existing"
        echo "CA Key full path: $cakey_existing_fp"


        echo "Existing CA Certificate:"
        echo "  '${ca_location}/{${cacert_existing}}'"
        until [[ -f "$cacert_existing_fp" ]]; do
            read -p "CA Certificate [$cacert_existing]: " cacert_existing
            [[ -z "$cacert_existing" ]] && cacert_existing=$default_cacert_existing
            cacert_existing_fp=${ca_location}/${cacert_existing}
            [[ ! -f $cacert_existing_fp ]] \
            && echo "cert-gen: cannot access '$cacert_existing_fp': No such file or directory"
        done
        echo "CA Certificate to: $cacert_existing"
        echo "CA Certificate full path: $cacert_existing_fp"
    else
        use_existing_ca="No"
        # ca_location=$ca_location
        # echo "CA Location: $ca_location"
        echo "This will generate new CA Certificate"
        echo ""
        echo "CA Config File:"
        
        [[ ! -z "$out_prefix" ]] && caconfig_file="$out_prefix-$caconfig_file"
        echo "  '${config_dir}/{${caconfig_file}}'"
        default_value=$caconfig_file
        until [[ -f "$caconfig_file_fp" ]]; do
            read -p "CA Config [$default_value]: " caconfig_file
            [[ -z "$caconfig_file" ]] && caconfig_file=$default_value
            caconfig_file_fp=${config_dir}/${caconfig_file}
            [[ ! -f $caconfig_file_fp ]] \
            && echo "cert-gen: cannot access '$caconfig_file_fp': No such file or directory"
        done
        echo "CA Config set to : $caconfig_file"
        echo "CA Config full path: $caconfig_file_fp"
    fi

    echo ""
    default_answer=No
    echo "Server Config File:"
    [[ ! -z "$out_prefix" ]] && config_file="$out_prefix-$config_file"
    echo "  '${config_dir}/{${config_file}}'"
    default_value=$config_file
    until [[ -f "$config_file_fp" ]]; do
        read -p "CA Config [$default_value]: " config_file
        [[ -z "$config_file" ]] && config_file=$default_value
        config_file_fp=${config_dir}/${config_file}
        [[ ! -f $config_file_fp ]] \
        && echo "cert-gen: cannot access '$config_file_fp': No such file or directory"
    done
    echo "Server Config file set to : $caconfig_file"
    echo "Server Config file full path: $caconfig_file_fp"
    
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
}

get_config() {
    if [ ! -d $config_dir ]; then
        echo "cert-gen: cannot access '$config_file_fp': No such file or directory"
        echo "Creating... '$config_dir' for future use"
        mkdir -p $config_dir
    fi

    if [ ! -f $config_file_fp ]; then
        echo "cert-gen: cannot access '$config_file_fp': No such file or directory"
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
    
    clear_screen
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
    clear_screen
    local ans
    
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                    Check CA Certificate"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "file:"
    echo "  $used_cacert"
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    openssl x509 -in $used_cacert -text -noout
    echo ""
    sleep 1

    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                     Check Server CSR"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "file:"
    echo "  $out_server_csr"
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    openssl req -in $out_server_csr -noout -text
    echo ""
    sleep 1

    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "                 Check Server Certificate"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "file:"
    echo "  $out_server_cert"
    echo ""
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    openssl x509 -in $out_server_cert -text -noout
    echo ""
    sleep 1

    ans=$(tr '[:upper:]' '[:lower:]' <<<$client_cert_create)
    if [[ "$ans" == 'y'  ||  "$ans" == 'yes'  ||  "$ans" == 'n'  ||  "$ans" == 'no' ]]; then
        if [[ "$ans" = "y" || "$ans" == "yes" ]]; then
        
            echo ""
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            echo "                       Check Client CSR"
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            echo "file:"
            echo "  $out_client_csr"
            echo ""
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            openssl req -in $out_client_csr -noout -text
            echo ""
            sleep 1

            echo ""
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            echo "                   Check Client Certificate"
            echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
            echo "file:"
            echo "  $out_client_cert"
            echo ""
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
    
    ans=$(tr '[:upper:]' '[:lower:]' <<<$use_existing_ca)
    if [ "$ans" == "yes" ]; then
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo "                 Use Existing: CA Private Key: "
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        if [ ! -f $used_cakey ]; then
            echo "CA Private Key::"
            echo "  '${used_cakey}}'"
            echo "NOT Exist!"
            exit 1
        fi

        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo "                 Use Existing: CA Certificate: "
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        if [ ! -f $used_cacert ]; then
            echo "CA Certificate::"
            echo "  '${used_cacert}}'"
            echo "NOT Exist!"
            echo ""
            exit 1
        fi
    else
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo "                 Generate CA Private Key"
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        if [ "$master_pass_is" == "True" ]; then
            cmd="openssl genrsa -aes256 -passout pass:$pass_phrase -out $used_cakey $rsa_bit"
        else
            cmd="openssl genrsa -aes256 -out $used_cakey $rsa_bit"
        fi
        if [ -f $used_cakey ]; then
            default_answer=Yes
            echo "CA Private Key Already Exist:"
            echo "  '${used_cakey}}'"
            if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
                echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-out\)/pass:**** -out/g'
                eval "$cmd"
            else
                echo "Using existing: $used_cakey"
            fi
        else
            echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-out\)/pass:**** -out/g'
            eval "$cmd"
        fi

        echo ""
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        echo "                Generate CA Certificate"
        echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
        if [ ! -f $caconfig_file_fp ]; then
            echo "CA Config file::"
            echo "  '${caconfig_file_fp}}'"
            echo "NOT Exist!"
            echo ""
            exit 1
        fi
        if [ "$master_pass_is" == "True" ]; then
            cmd="openssl req -new -x509 -days $days -passin pass:$pass_phrase -key $used_cakey -sha256 -out $used_cacert -config $caconfig_file_fp"
        else
            cmd="openssl req -new -x509 -days $days -key $used_cakey -sha256 -out $used_cacert -config $caconfig_file_fp"
        fi
        if [ -f $used_cacert ]; then
            default_answer=Yes
            echo "CA Certificate Already Exist:"
            echo "  '${used_cacert}'"
            if yesno --default $default_answer "overwrite? (Yes|No) [$default_answer] "; then
                echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-key\)/pass:**** -key/g'
                eval "$cmd"
            else
                echo "Using existing: $used_cacert"
            fi
        else
            echo "$cmd" | sed -e 's/\(pass:.\{1,\}\s\-key\)/pass:**** -key/g'
            eval "$cmd"
        fi
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
    echo "       Generate Server Certificate Signing Request (CSR)"
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
        cmd="openssl x509 -req -sha256 -days $days -passin pass:$pass_phrase -in $out_server_csr -CA $used_cacert -CAkey $used_cakey -CAcreateserial -signkey $out_server_key -out $out_server_cert"
    else
        cmd="openssl x509 -req -sha256 -days $days -in $out_server_csr -CA $used_cacert -CAkey $used_cakey -CAcreateserial -signkey $out_server_key -out $out_server_cert"
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
            cmd2="openssl x509 -req -days $days -sha256 -in $out_client_csr -passin pass:$pass_phrase -CA $used_cacert -CAkey $used_cakey -CAcreateserial -out $out_client_cert -extfile $out_client_extfile"
        else
            cmd1="echo 'extendedKeyUsage = clientAuth' > $out_client_extfile"
            cmd2="openssl x509 -req -days $days -sha256 -in $out_client_csr -CA $used_cacert -CAkey $used_cakey -CAcreateserial -out $out_client_cert -extfile $out_client_extfile"
        fi
        if [ -f $out_client_cert ]; then
            default_answer=Yes
            echo "Client Signed Certificate Already Exist:"
            echo "  '${out_client_cert}'"
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

clear_screen
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