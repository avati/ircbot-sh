#!/bin/bash


#######################################################
#######################################################
##########
##########  configuration parameters in _init
##########
#######################################################
#######################################################


_init()
{
    NICK=${NICK:-"avati"};
    PASSWORD=${PASSWORD:-"measdfasdfasf"};
    IDENT=${IDENT:-${NICK}};
    PORT=${PORT:-"6667"};
    IRCNAME=${IRCNAME:-${NICK}};
    SERVER=${SERVER:-"irc.freenode.net"};
    CHANNELS="#SJCE #GLUSTER";

    IFS="${IFS}"$(echo -ne "\r");

    exec 3>/dev/tcp/${SERVER}/${PORT} && exec 0<&3
}



###########################################################
###########################################################
##########
##########      irc_<event>_callback - customize bot here
##########
###########################################################
###########################################################


#####
#####  Callback on receiving NOTICE type message
#####

irc_notice_callback()
{
    local FROM="${1}";
    local TO="${2}";
    local MSG="${3}";

    echo "-Notice- ${1}/${2} ${MSG}";

    [ "${FROM}" = "NickServ" ] && {
	[ "x$foo" = "x" ] &&
	echo "NICKSERV IDENTIFY ${PASSWORD}" >&3;
	foo="y"
	return;
    }
}


#####
##### Callback on receving a PRIVMSG
#####   Both messages to channels and private
#####   messages are handled here
#####   ${TO} will be "#channel" or ${NICK} accordingly
#####

irc_msg_callback()
{
    local FROM="${1}";
    local TO="${2}";
    local MSG="${3}";

    echo "-Msg- ${FROM}/${TO} ${MSG}";

    [ "${MSG}" = $(echo -ne ":\001VERSION\001") ] && {
	echo "NOTICE ${FROM} "$(echo -ne ":\001VERSION ") " I am a shell script, damnit!"$(echo -ne "\001") >&3;
	return;
    }
}


#####
##### Callback when somebody joins a channel
#####

irc_join_callback()
{
    local JOINEE=$1;
    local CHANNEL=$2;
    echo "-Join- ${JOINEE} joined ${CHANNEL} -end-";
    local MSG=":${JOINEE}";

    local repeat=$(( 3 + $(( $RANDOM % 5 ))));
    local i=0;
    for (( i=0 ; $i<$repeat ; i++ ))
    do
      MSG="${MSG} ${JOINEE}";
    done
    MSG="${MSG} !!!!!!!!!!!!!!!!!!!!!!!!!!!";
    [ "${JOINEE}" != "${NICK}" ] && irc_cmd_msg ${CHANNEL} "${MSG}";
}


#####
##### Callback when you/sombody get/s kicked
#####

irc_kick_callback()
{
    local KICKER=$1;
    local KICKEE=$2;
    local CHANNEL=$3;
    local REASON=$4;

    if [ "${KICKEE}" = "${NICK}" ]
    then
	irc_cmd_join "${CHANNEL}";
	irc_cmd_msg "${CHANNEL}" ":Grrrrrr! ${KICKER}!!!";
    else
	if [ "${KICKER}" = "${NICK}" ]
	then
	    irc_cmd_msg "${CHANNEL}" ":there goes ${KICKEE} ...";
	else
	    irc_cmd_msg "${CHANNEL}" ":haha, well done ${KICKER}! ${REASON} :P";
	fi
    fi
}

#####
##### Callback when somebody leaves a channel
#####

irc_part_callback()
{
    local WHO=$1;
    local CHANNEL=$2;
    local REASON="$3";

    irc_cmd_msg "${CHANNEL}" ":${WHO} come back :(";
}

#####
##### Callback when sombody changes nick
#####

irc_nick_callback()
{
    local OLDNICK=$1;
    local NEWNICK=$2;

    [ "${OLDNICK}" = "${NICK}" ] && NICK="${NEWNICK}" ||
    irc_cmd_msg "${NEWNICK}" ":${OLDNICK} was a better nick i think";
}

##############################################
##############################################
######                          ##############
######    irc_cmd_* commands    ##############
######                          ##############
##############################################
##############################################

irc_cmd_join()
{
    local CHANNEL="${1}";
    echo ":foo JOIN ${CHANNEL}" >&3;
}

irc_cmd_msg()
{
    local TO="${1}";
    local MSG="${2}";
    echo ":foo PRIVMSG ${TO} ${MSG}" >&3;
    echo "-Send- ${TO} ${MSG} -Over-";
}

nick_from_ident()
{
    local IDENT="${1}";
    local oldIFS="${IFS}";
    IFS=":!";
    set ${1};
    echo "${2}";
    IFS="${oldIFS}";
}

irc_cmd_register()
{
    echo "USER ${IDENT} localhost ${SERVER} :${IRCNAME}" >&3;
    echo "NICK ${NICK}" >&3;
}


irc_cmd_pong()
{
    local oldIFS="${IFS}";
    echo "PONG :foo" >&3;
}

#########################################
#########################################
###### 
###### Initialization
######
#########################################
#########################################

irc_initial_join()
{
    set ${CHANNELS};
    for chan in $@
    do
      irc_cmd_join "${chan}";
      irc_cmd_msg ${chan} ":"$(echo -ne "\001")"ACTION is backkk"$(echo -ne "\001");
    done
}


###################################################
###################################################
#####
#####  IRC message handlers
#####
###################################################
###################################################

irc_handle_notice()
{
    local FULLMSG="$@";
    oldIFS="${IFS}";
    IFS=":!${IFS}";
    set $@;
    local FROM=$2;
    local TO=$5;
    IFS="${oldIFS}";
    set ${FULLMSG};
    shift ; shift ; shift;
    local MSG="$@";
    IFS="${oldIFS}";
    irc_notice_callback "${FROM}" "${TO}" "${MSG}";

    return 0;
}

irc_handle_join()
{
    local JOINEE=$(nick_from_ident $1);
    local oldIFS="${IFS}";
    IFS=":${IFS}";
    set $@;
    local CHANNEL=$4;
    IFS="${oldIFS}";
    irc_join_callback "${JOINEE}" $CHANNEL;

    return 0;
}

irc_handle_kick()
{
    set $@;

    local KICKER=$(nick_from_ident $1);
    local KICKEE=$4;
    local CHANNEL=$3;
    shift; shift; shift; shift;
    local REASON="$*";

    irc_kick_callback "${KICKER}" "${KICKEE}" "${CHANNEL}" "${REASON}";

    return 0;
}

irc_handle_message()
{
    local FULLMSG="$@";
    oldIFS="${IFS}";
    IFS=":!${IFS}";
    set $@;
    local FROM=$2;
    local TO=$5;
    IFS="${oldIFS}";
    set ${FULLMSG};
    shift ; shift ; shift;
    local MSG="$@";
    IFS="${oldIFS}";
    irc_msg_callback "${FROM}" "${TO}" "${MSG}";

    return 0;
}

irc_handle_part ()
{
    set $1;
    local WHO=$(nick_from_ident $1);
    local CHANNEL=$3;
    shift; shift; shift;
    local REASON="$*";

    irc_part_callback "${WHO}" "${CHANNEL}" "${REASON}";
}

irc_handle_nick ()
{
    local ORIG="$@";
    set $1;
    local OLDNICK=$(nick_from_ident $1);
    local oldIFS="${IFS}";
    IFS=":"$(echo -en "\r");
    set ${ORIG};
    local NEWNICK=$3;
    IFS="${oldIFS}";

    irc_nick_callback "${OLDNICK}" "${NEWNICK}";
}

irc_parse()
{
    local ORIG="$1";
    set $1;

    case "${2}" in
	NOTICE) 
	    irc_handle_notice "${ORIG}";
	    ;;
	PRIVMSG)
	    irc_handle_message "${ORIG}";
	    ;;
	JOIN)
	    irc_handle_join "${ORIG}";
	    ;;
	KICK) 
	    irc_handle_kick "${ORIG}";
	    ;;
	PART)
	    irc_handle_part "${ORIG}";
	    ;;
	NICK)
	    irc_handle_nick "${ORIG}";
	    ;;
    esac

    case "$1" in
	PING)
	    irc_cmd_pong "${ORIG}";
	    ;;
    esac
	
}

main()
{
    irc_cmd_register;
    irc_initial_join;

    while read line
    do
      irc_parse "${line}";
    done
}

_init "$@" && main "$@"
