#!/bin/bash -e
# Kubernetes Bastion Bootstrapping

# Configuration
PROGRAM='Kubernetes Bastion'

##################################### Functions Definitions
function checkos () {
    echo "${FUNCNAME[0]} Started ..."
    platform='unknown'
    unamestr=`uname`
    if [[ "$unamestr" == 'Linux' ]]; then
        platform='linux'
    else
        echo "[WARNING] This script is not supported on MacOS or freebsd"
        exit 1
    fi
    echo "${FUNCNAME[0]} Ended"
}

function usage () {
    echo "$0 <usage>"
    echo " "
    echo "options:"
    echo -e "--help \t Show options for this script"
    echo -e "--banner \t Enable or Disable Bastion Message"
    echo -e "--enable \t SSH Banner"
    echo -e "--tcp-forwarding \t Enable or Disable TCP Forwarding"
    echo -e "--x11-forwarding \t Enable or Disable X11 Forwarding"
}

function chkstatus () {
    echo "${FUNCNAME[0]} Started ..."
    if [ $? -eq 0 ]
    then
        echo "Script [PASS]"
    else
        echo "Script [FAILED]" >&2
        exit 1
    fi
}

function osrelease () {
    echo "${FUNCNAME[0]} Started ..."
    OS=`cat /etc/os-release | grep '^NAME=' |  tr -d \" | sed 's/\n//g' | sed 's/NAME=//g'`
    if [ "$OS" == "Ubuntu" ]; then
        echo "Ubuntu"
    elif [ "$OS" == "Amazon Linux AMI" ]; then
        echo "AMZN"
    elif [ "$OS" == "CentOS Linux" ]; then
        echo "CentOS"
    else
        echo "Operating System Not Found"
    fi
    echo "${FUNCNAME[0]} Ended" >> /var/log/cfn-init.log
}


function request_eip() {
    echo "${FUNCNAME[0]} Started ..."
    release=$(osrelease)
    export Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`

    #Check if EIP already assigned.
    ALLOC=1
    ZERO=0
    INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
    ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
    if [ "$ASSIGNED" -gt "$ZERO" ]; then
        echo "Already assigned an EIP."
    else
        aws ec2 describe-addresses --region $Region --output text > /query.txt
        #Ensure we are only using EIPs from our Stack
        line=`curl http://169.254.169.254/latest/user-data/ | grep EIP_LIST`
        IFS=$':' DIRS=(${line//$','/:})       # Replace tabs with colons.

        for (( i=0 ; i<${#DIRS[@]} ; i++ )); do
            EIP=`echo ${DIRS[i]} | sed 's/\"//g' | sed 's/EIP_LIST=//g'`
            if [ $EIP != "Null" ]; then
                #echo "$i: $EIP"
                grep "$EIP" /query.txt >> /query2.txt;
            fi
        done
        mv /query2.txt /query.txt


        AVAILABLE_EIPs=`cat /query.txt | wc -l`

        if [ "$AVAILABLE_EIPs" -gt "$ZERO" ]; then
            FIELD_COUNT="5"
            INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
            echo "Running associate_eip_now"
            while read name;
            do
                #EIP_ENTRY=$(echo $name | grep eip | wc -l)
                EIP_ENTRY=$(echo $name | grep eni | wc -l)
                echo "EIP: $EIP_ENTRY"
                if [ "$EIP_ENTRY" -eq 1 ]; then
                    echo "Already associated with an instance"
                    echo ""
                else
                    export EIP=`echo "$name" | sed 's/[\s]+/,/g' | awk {'print $4'}`
                    EIPALLOC=`echo $name | awk {'print $2'}`
                    echo "NAME: $name"
                    echo "EIP: $EIP"
                    echo "EIPALLOC: $EIPALLOC"
                    aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $EIPALLOC --region $Region
                fi
            done < /query.txt
        else
            echo "[ERROR] No Elastic IPs available in this region"
            exit 1
        fi

        INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
        ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
        if [ "$ASSIGNED" -eq 1 ]; then
            echo "EIP successfully assigned."
        else
            #Retry
            while [ "$ASSIGNED" -eq "$ZERO" ]
            do
                sleep 3
                request_eip
                INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
                ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
            done
        fi
    fi

    echo "${FUNCNAME[0]} Ended"
}

function call_request_eip() {
    echo "${FUNCNAME[0]} Started ..."
    Region=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev`
    ZERO=0
    INSTANCE_IP=`ifconfig -a | grep inet | awk {'print $2'} | sed 's/addr://g' | head -1`
    ASSIGNED=$(aws ec2 describe-addresses --region $Region --output text | grep $INSTANCE_IP | wc -l)
    if [ "$ASSIGNED" -gt "$ZERO" ]; then
        echo "Already assigned an EIP."
    else
        WAIT=$(shuf -i 1-30 -n 1)
	echo "Waiting for $WAIT ..."
        sleep "$WAIT"
        request_eip
    fi
    echo "${FUNCNAME[0]} Ended"
}

function prevent_process_snooping() {
    echo "${FUNCNAME[0]} Started ..."
    # Prevent bastion host users from viewing processes owned by other users.
    mount -o remount,rw,hidepid=2 /proc
    awk '!/proc/' /etc/fstab > temp && mv temp /etc/fstab
    echo "proc /proc proc defaults,hidepid=2 0 0" >> /etc/fstab
    echo "${FUNCNAME[0]} Ended"
}

##################################### End Function Definitions

# Call checkos to ensure platform is Linux
checkos

## set an initial value
SSH_BANNER="LINUX BASTION"

# Read the options from cli input
TEMP=`getopt -o h:  --long help,banner:,enable:,tcp-forwarding:,x11-forwarding: -n $0 -- "$@"`
eval set -- "$TEMP"


if [ $# == 1 ] ; then echo "No input provided! type ($0 --help) to see usage help" >&2 ; exit 1 ; fi

# extract options and their arguments into variables.
while true; do
    case "$1" in
        -h | --help)
            usage
            exit 1
            ;;
        --banner)
            BANNER_PATH="$2";
            shift 2
            ;;
        --enable)
            ENABLE="$2";
            shift 2
            ;;
        --tcp-forwarding)
            TCP_FORWARDING="$2";
            shift 2
            ;;
        --x11-forwarding)
            X11_FORWARDING="$2";
            shift 2
            ;;
        --)
            break
            ;;
        *)
            break
            ;;
    esac
done

# BANNER CONFIGURATION
BANNER_FILE="/etc/ssh_banner"
if [[ $ENABLE == "true" ]];then
    if [ -z ${BANNER_PATH} ];then
        echo "BANNER_PATH is null skipping ..."
    else
        echo "BANNER_PATH = ${BANNER_PATH}"
        echo "Creating Banner in ${BANNER_FILE}"
        if [ $BANNER_FILE ] ;then
            echo "[INFO] Installing banner ... "
            echo -e "\n Banner ${BANNER_FILE}" >>/etc/ssh/sshd_config
        else
            echo "[INFO] banner file is not accessible skipping ..."
            exit 1;
        fi
    fi
else
    echo "Banner message is not enabled!"
fi

release=$(osrelease)

prevent_process_snooping

call_request_eip

systemctl restart ssh sshd

echo "Bootstrap complete."

exit 0
