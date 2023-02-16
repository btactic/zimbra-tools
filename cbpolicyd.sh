#!/bin/bash

# Copyright (C) 2016-2023  Barry de Graaff
# 
# Bugs and feedback: https://github.com/Zimbra-Community/zimbra-tools/issues
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/.

set -e
# if you want to trace your script uncomment the following line
# set -x
# Documentation used from https://www.zimbrafr.org/forum/topic/7623-poc-zimbra-policyd/
# https://wiki.zimbra.com/wiki/Postfix_Policyd#Example_Configuration
# Thanks 

# DEFAULT VALUES

CBPOLICYD_DB_USER="ad-policyd_db"
DEFAULT_CBPOLICYD_DB_HOSTNAME="127.0.0.1"
CBPOLICYD_DB_NAME="policyd_db"
CBPOLICYD_DB_PORT="3306"
CBPOLICYD_DB_USER_ALLOWED_HOST='*'

CBPOLICYD_SENDER_PERIOD="60"
CBPOLICYD_SENDER_MESSAGECOUNT="100"
CBPOLICYD_RECIPIENT_PERIOD="60"
CBPOLICYD_RECIPIENT_MESSAGECOUNT="125"

usage() {
cat <<EOF
  Copyright (C) 2023 BTACTIC, SCCL
  Copyright (C) 2016-2023  Barry de Graaff
  Licensed under the GNU PUBLIC LICENSE 3.0

  SERVER MODE
  ===========
  Usage: $0 --server
  Server mode use default parametres to setup itself.

  CLIENT MODE
  ===========
  Usage: $0 --client --hostname=HOSTNAME --password=PASSWORD
  Example: $0 --client --hostname=192.168.1.100 --password=MYS3CR3T
  You need to specify both hostname and password in client mode.

  COMMON OPTIONS
  ==============
    --user=USERNAME
    CBPolicyd DB Username. Default: ${CBPOLICYD_DB_USER}

    --hostname=HOSTNAME
    CBPolicyd DB Hostname. Default (for server mode only): ${DEFAULT_CBPOLICYD_DB_HOSTNAME}

    --port=PORT
    CBPolicyd DB Port. Default: ${CBPOLICYD_DB_PORT}

    --password=PASSWORD
    CBPolicyd DB Password

    --sender-period=SENDER_PERIOD
    CBPolicyd Sender Period to use as a base to limit.
    Default: ${CBPOLICYD_SENDER_PERIOD}

    --sender-messagecount=SENDER_MESSAGECOUNT
    CBPolicyd Sender Messagecount to use as a base to limit.
    Default: ${CBPOLICYD_SENDER_MESSAGECOUNT}

    --recipient-period=RECIPIENT_PERIOD
    CBPolicyd Recipient Period to use as a base to limit.
    Default: ${CBPOLICYD_RECIPIENT_PERIOD}

    --recipient-messagecount=RECIPIENT_MESSAGECOUNT
    CBPolicyd Recipient Messagecount to use as a base to limit.
    Default: ${CBPOLICYD_RECIPIENT_MESSAGECOUNT}

EOF

}

MYSQL_CLI="/usr/bin/mysql"
TOO_MANY_EMAILS_MESSAGE="Esta mandando demasiados mensajes en muy poco tiempo. Pruebe mas tarde."

echo "Automated cbpolicd installer for single-server. Tested on Zimbra 8.8.15 p7 CentOS7, Zimbra 9.0.0 p29 CentOS 7, Zimbra 9.0.0 patch 29 on Ubuntu 20, Zimbra 10 on Ubuntu 20.
- Installs policyd on MariaDB or MySQL (shipped with Zimbra) and show commands on how to activate on Zimbra
- No webui is installed"

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# By default no server mode or client mode is requested.
SERVER_MODE="NO"
CLIENT_MODE="NO"

# Check the arguments.
for option in "$@"; do
  case "$option" in
    -h | --help)
      usage
      exit 0
    ;;
    --user=*)
      CBPOLICYD_DB_USER=`echo "$option" | sed 's/--user=//'`
    ;;
    --hostname=*)
      CBPOLICYD_DB_HOSTNAME=`echo "$option" | sed 's/--hostname=//'`
    ;;
    --port=*)
      CBPOLICYD_DB_PORT=`echo "$option" | sed 's/--port=//'`
    ;;
    --password=*)
      CBPOLICYD_DB_PASSWORD=`echo "$option" | sed 's/--password=//'`
    ;;
    --sender-period=*)
      CBPOLICYD_SENDER_PERIOD=`echo "$option" | sed 's/--sender-period=//'`
    ;;
    --sender-messagecount=*)
      CBPOLICYD_SENDER_MESSAGECOUNT=`echo "$option" | sed 's/--sender-messagecount=//'`
    ;;
    --recipient-period=*)
      CBPOLICYD_RECIPIENT_PERIOD=`echo "$option" | sed 's/--recipient-period=//'`
    ;;
    --recipient-messagecount=*)
      CBPOLICYD_RECIPIENT_MESSAGECOUNT=`echo "$option" | sed 's/--recipient-messagecount=//'`
    ;;
    --client)
      CLIENT_MODE="YES"
    ;;
    --server)
      SERVER_MODE="YES"
    ;;
  esac
done

# Check if server mode and client mode were requested at the same time
if [ "x${SERVER_MODE}" = "xYES" ] && [ "x${CLIENT_MODE}" = "xYES" ] ; then
  echo "--client and --server cannot be used simultaneously."
  echo "Aborting..."
  exit 1
fi

# We need either server mode or cliente mode
if [ "x${SERVER_MODE}" = "xYES" ] || [ "x${CLIENT_MODE}" = "xYES" ] ; then
  :
else
  echo "Either --client or --server needs to be specified."
  echo "Aborting..."
  exit 1
fi

# If hostname is empty at this point and we are in server mode we override it with the default value
if [ "x${SERVER_MODE}" = "xYES" ] && [ "x" = "x${CBPOLICYD_DB_HOSTNAME}" ] ; then
  CBPOLICYD_DB_HOSTNAME="${DEFAULT_CBPOLICYD_DB_HOSTNAME}"
fi

# If password is empty at this point and we are in server mode we generate a random value
if [ "x${SERVER_MODE}" = "xYES" ] && [ "x" = "x${CBPOLICYD_DB_PASSWORD}" ] ; then
  CBPOLICYD_DB_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-10};echo;)
fi

# Ensure that Client mode has a hostname
if [ "x${CLIENT_MODE}" = "xYES" ] && [ "x" = "x${CBPOLICYD_DB_HOSTNAME}" ] ; then
  echo "--client needs a non empty --hostname"
  echo "Aborting..."
  exit 1
fi

# Ensure that Client mode has a password
if [ "x${CLIENT_MODE}" = "xYES" ] && [ "x" = "x${CBPOLICYD_DB_PASSWORD}" ] ; then
  echo "--client needs a non empty --password"
  echo "Aborting..."
  exit 1
fi

# Check that at this point all of the variables have some kind of data

# Non empty db user
if [ "x" = "x${CBPOLICYD_DB_USER}" ] ; then
  echo "Empty --user"
  echo "Aborting..."
  exit 1
fi

# Non empty db hostname
if [ "x" = "x${CBPOLICYD_DB_HOSTNAME}" ] ; then
  echo "Empty --hostname"
  echo "Aborting..."
  exit 1
fi

# Non empty db port
if [ "x" = "x${CBPOLICYD_DB_PORT}" ] ; then
  echo "Empty --port"
  echo "Aborting..."
  exit 1
fi

# Non empty db password
if [ "x" = "x${CBPOLICYD_DB_PASSWORD}" ] ; then
  echo "Empty --password"
  echo "Aborting..."
  exit 1
fi

# Non empty sender period
if [ "x" = "x${CBPOLICYD_SENDER_PERIOD}" ] ; then
  echo "Empty --sender-period"
  echo "Aborting..."
  exit 1
fi

# Non empty sender messagecount
if [ "x" = "x${CBPOLICYD_SENDER_MESSAGECOUNT}" ] ; then
  echo "Empty --sender-messagecount"
  echo "Aborting..."
  exit 1
fi

# Non empty recipient period
if [ "x" = "x${CBPOLICYD_RECIPIENT_PERIOD}" ] ; then
  echo "Empty --recipient-period"
  echo "Aborting..."
  exit 1
fi

# Non empty recipient messagecount
if [ "x" = "x${CBPOLICYD_RECIPIENT_MESSAGECOUNT}" ] ; then
  echo "Empty --recipient-messagecount"
  echo "Aborting..."
  exit 1
fi

# MAIN PROGRAM

if [ "x${SERVER_MODE}" = "xYES" ] ; then

  # creating a user, just to make sure we have one (for mysql on CentOS 6, so we can execute the next mysql queries w/o errors)
  POLICYDDBCREATE="$(mktemp /tmp/policyd-dbcreate.XXXXXXXX.sql)"
  cat <<EOF > "${POLICYDDBCREATE}"
  CREATE DATABASE ${CBPOLICYD_DB_NAME} CHARACTER SET 'UTF8';
  CREATE USER '${CBPOLICYD_DB_USER}'@'${CBPOLICYD_DB_USER_ALLOWED_HOST}' IDENTIFIED BY '${CBPOLICYD_DB_PASSWORD}';
  GRANT ALL PRIVILEGES ON ${CBPOLICYD_DB_NAME} . * TO '${CBPOLICYD_DB_USER}'@'${CBPOLICYD_DB_USER_ALLOWED_HOST}' WITH GRANT OPTION;
  FLUSH PRIVILEGES ;
EOF

  "${MYSQL_CLI}" --force < "${POLICYDDBCREATE}" > /dev/null 2>&1

  cat <<EOF > "${POLICYDDBCREATE}"
  DROP USER '${CBPOLICYD_DB_USER}'@'${CBPOLICYD_DB_USER_ALLOWED_HOST}';
  DROP DATABASE ${CBPOLICYD_DB_NAME};
  CREATE DATABASE ${CBPOLICYD_DB_NAME} CHARACTER SET 'UTF8';
  CREATE USER '${CBPOLICYD_DB_USER}'@'${CBPOLICYD_DB_USER_ALLOWED_HOST}' IDENTIFIED BY '${CBPOLICYD_DB_PASSWORD}';
  GRANT ALL PRIVILEGES ON ${CBPOLICYD_DB_NAME} . * TO '${CBPOLICYD_DB_USER}'@'${CBPOLICYD_DB_USER_ALLOWED_HOST}' WITH GRANT OPTION;
  FLUSH PRIVILEGES ;
EOF

  echo "Creating database and user"
  "${MYSQL_CLI}" < "${POLICYDDBCREATE}"

  if [ -d "/opt/zimbra/common/share/database/" ]; then
    #shipped version from Zimbra (8.7)
    cd /opt/zimbra/common/share/database/ >/dev/null
  else
    #shipped version from Zimbra (8.6)
    cd /opt/zimbra/cbpolicy*/share/database/ >/dev/null
  fi

  POLICYDTABLESSQL="$(mktemp /tmp/policyd-dbtables.XXXXXXXX.sql)"
  for i in core.tsql access_control.tsql quotas.tsql amavis.tsql checkhelo.tsql checkspf.tsql greylisting.tsql accounting.tsql;
      do
      ./convert-tsql mysql $i;
      done > "${POLICYDTABLESSQL}"

  # have to replace TYPE=InnoDB with ENGINE=InnoDB, this is not needed when using the latest upstream version of cbpolicyd
  # but it seems to be an issue in the version shipped with Zimbra 8.6 (not 8.7)
  if grep --quiet -e "TYPE=InnoDB" "${POLICYDTABLESSQL}"; then
    grep -lZr -e "TYPE=InnoDB" "${POLICYDTABLESSQL}" | xargs -0 sed -i "s^TYPE=InnoDB^ENGINE=InnoDB^g"
  fi

  echo "Populating ${CBPOLICYD_DB_NAME} please wait..."
  "${MYSQL_CLI}" ${CBPOLICYD_DB_NAME} < "${POLICYDTABLESSQL}"

  POLICYDPOLICYSQL="$(mktemp /tmp/policyd-policy.XXXXXXXX.sql)"
  cat <<EOF > "${POLICYDPOLICYSQL}"
  INSERT INTO policies (ID, Name,Priority,Description) VALUES(6, 'Zimbra CBPolicyd Policies', 0, 'Zimbra CBPolicyd Policies');
  INSERT INTO policy_members (PolicyID,Source,Destination) VALUES(6, 'any', 'any');
  INSERT INTO quotas (PolicyID,Name,Track,Period,Verdict,Data) VALUES (6, 'Sender:user@domain','Sender:user@domain', ${CBPOLICYD_SENDER_PERIOD}, 'DEFER', '${TOO_MANY_EMAILS_MESSAGE}');
  INSERT INTO quotas (PolicyID,Name,Track,Period,Verdict) VALUES (6, 'Recipient:user@domain', 'Recipient:user@domain', ${CBPOLICYD_RECIPIENT_PERIOD}, 'REJECT');
  INSERT INTO quotas_limits (QuotasID,Type,CounterLimit) VALUES(3, 'MessageCount', ${CBPOLICYD_SENDER_MESSAGECOUNT});
  INSERT INTO quotas_limits (QuotasID,Type,CounterLimit) VALUES(4, 'MessageCount', ${CBPOLICYD_RECIPIENT_MESSAGECOUNT});
EOF

  echo "Setting basic quota policy"

  "${MYSQL_CLI}" ${CBPOLICYD_DB_NAME} < "${POLICYDPOLICYSQL}"

  echo "Installing reporting commands"
  echo ""${MYSQL_CLI}" ${CBPOLICYD_DB_NAME} -e \"select count(instance) count, sender from session_tracking where date(from_unixtime(unixtimestamp))=curdate() group by sender order by count desc;\"" > /usr/local/sbin/cbpolicyd-report
  chmod +rx /usr/local/sbin/cbpolicyd-report

fi

# TODO : Check that every setting is set

CBPOLICYDCONF="$(mktemp /tmp/cbpolicyd.conf.in.XXXXXXXX)"
echo "Backing up cbpolicyd.conf.in"
cp -a /opt/zimbra/conf/cbpolicyd.conf.in ${CBPOLICYDCONF}

echo "Setting username in /opt/zimbra/conf/cbpolicyd.conf.in"
grep -lZr -e ".*sername=.*$" "/opt/zimbra/conf/cbpolicyd.conf.in" | xargs -0 sed -i "s^.*sername=.*$^Username=${CBPOLICYD_DB_USER}^g"

echo "Setting password in /opt/zimbra/conf/cbpolicyd.conf.in"
grep -lZr -e ".*assword=.*$" "/opt/zimbra/conf/cbpolicyd.conf.in"  | xargs -0 sed -i "s^.*assword=.*$^Password=${CBPOLICYD_DB_PASSWORD}^g"

echo "Setting database in /opt/zimbra/conf/cbpolicyd.conf.in"
grep -lZr -e "DSN=.*$" "/opt/zimbra/conf/cbpolicyd.conf.in"  | xargs -0 sed -i "s^DSN=.*$^DSN=DBI:mysql:database=${CBPOLICYD_DB_NAME};host=${CBPOLICYD_DB_HOSTNAME};port=${CBPOLICYD_DB_PORT}^g"

echo "--------------------------------------------------------------------------------------------------------------
CBPolicyd installed successful
"

if [ "x${SERVER_MODE}" = "xYES" ] ; then
  echo "--------------------------------------------------------------------------------------------------------------
The following policy is installed:
- Rate limit any sender from sending more then 100 emails every 60 seconds. Messages beyond this limit are deferred.
- Rate limit any @domain from receiving more then 125 emails in a 60 second period. Messages beyond this rate are rejected.

For your reference:
- Database ${CBPOLICYD_DB_NAME} and user have been created using:
  ${POLICYDDBCREATE}
- Database structure has been created using:
  ${POLICYDTABLESSQL}
- The quota/rate limiting policy has been created using:
  ${POLICYDPOLICYSQL}

Here are some tips:
- You can run /usr/local/sbin/cbpolicyd-report
  to show message count by sender/day
- You can change or review your polcies using mysql client:
  ${MYSQL_CLI} ${CBPOLICYD_DB_NAME}
  SELECT * FROM quotas_limits;
  UPDATE quotas_limits SET CounterLimit = 30 WHERE ID = 4;

--------------------------------------------------------------------------------------------------------------
"
fi

echo "--------------------------------------------------------------------------------------------------------------
- A configuration backup is in:
  ${CBPOLICYDCONF}   
- Running config is in:
  /opt/zimbra/conf/cbpolicyd.conf.in
- Database clean-up is scheduled daily at 03:35AM using
  the default zimbra cron

Here are some tips:
- On Zimbra patches and upgrades, you may need to re-run
  this script or re-apply the configuration  

To activate your configuration, run as zimbra user:
zmprov ms \$(zmhostname) +zimbraServiceEnabled cbpolicyd
zmprov ms \$(zmhostname) zimbraCBPolicydQuotasEnabled TRUE

Rebooting your server will tell the MTA to start using cbpolicyd and works for sure.
You can also try using zmmtactl restart and zmcbpolicydctl start (in that order!). 
Testing shows that using zmcontrol restart does not enable cbpolicyd.

You can find logging here:
tail -f /opt/zimbra/log/cbpolicyd.log
--------------------------------------------------------------------------------------------------------------
"
