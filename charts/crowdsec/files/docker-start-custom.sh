#!/bin/bash

#### This is based on the docker entrypoint script, but in k8s, this script is only used for LAPI pods.
#### Therefore, all agent-related configuration has been removed and check if LAPI is disabled (as the pod will not be created in that case).

# shellcheck disable=SC2292      # allow [ test ] syntax
# shellcheck disable=SC2310      # allow "if function..." syntax with -e

set -e
shopt -s inherit_errexit

# Note that "if function_name" in bash matches when the function returns 0,
# meaning successful execution.

# match true, TRUE, True, tRuE, etc.
istrue() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    true) return 0 ;;
    *) return 1 ;;
  esac
}

isfalse() {
    if istrue "$1"; then
        return 1
    else
        return 0
    fi
}

if istrue "$DEBUG"; then
    set -x
    export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi

if istrue "$CI_TESTING"; then
    echo "githubciXXXXXXXXXXXXXXXXXXXXXXXX" >/etc/machine-id
fi

#- DEFAULTS -----------------------#

export CONFIG_FILE="${CONFIG_FILE:=/etc/crowdsec/config.yaml}"
export CUSTOM_HOSTNAME="${CUSTOM_HOSTNAME:=localhost}"

#- HELPER FUNCTIONS ----------------#

# csv2yaml <string>
# generate a yaml list from a comma-separated string of values
csv2yaml() {
    [ -z "$1" ] && return
    echo "$1" | sed 's/,/\n- /g;s/^/- /g'
}

# wrap cscli with the correct config file location
cscli() {
    command cscli -c "$CONFIG_FILE" "$@"
}

# conf_get <key> [file_path]
# retrieve a value from a file (by default $CONFIG_FILE)
conf_get() {
    if [ $# -ge 2 ]; then
        yq e "$1" "$2"
    else
        cscli config show-yaml | yq e "$1"
    fi
}

# conf_set <yq_expression> [file_path]
# evaluate a yq command (by default on $CONFIG_FILE),
# create the file if it doesn't exist
conf_set() {
    if [ $# -ge 2 ]; then
        YAML_FILE="$2"
    else
        YAML_FILE="$CONFIG_FILE"
    fi
    if [ ! -f "$YAML_FILE" ]; then
        install -m 0600 /dev/null "$YAML_FILE"
    fi
    yq e "$1" -i "$YAML_FILE"
}

# conf_set_if(): used to update the configuration
# only if a given variable is provided
# conf_set_if "$VAR" <yq_expression> [file_path]
conf_set_if() {
    if [ "$1" != "" ]; then
        shift
        conf_set "$@"
    fi
}

# register_bouncer <bouncer_name> <bouncer_key>
register_bouncer() {
  if ! cscli bouncers list -o json | sed '/^ *"name"/!d;s/^ *"name": "\(.*\)",/\1/' | grep -q "^${1}$"; then
      if cscli bouncers add "$1" -k "$2" > /dev/null; then
          echo "Registered bouncer for $1"
      else
          echo "Failed to register bouncer for $1"
      fi
  fi
}

# Call cscli to manage objects ignoring taint errors
# $1 can be collections, parsers, etc.
# $2 can be install, remove, upgrade
# $3 is a list of object names separated by space
cscli_if_clean() {
    local itemtype="$1"
    local action="$2"
    local objs=$3
    shift 3
    # loop over all objects
    for obj in $objs; do
        if cscli "$itemtype" inspect "$obj" -o json | yq -e '.tainted // false' >/dev/null 2>&1; then
            echo "Object $itemtype/$obj is tainted, skipping"
        elif cscli "$itemtype" inspect "$obj" -o json | yq -e '.local // false' >/dev/null 2>&1; then
            echo "Object $itemtype/$obj is local, skipping"
        else
#            # Too verbose? Only show errors if not in debug mode
#            if [ "$DEBUG" != "true" ]; then
#                error_only=--error
#            fi
            error_only=""
            echo "Running: cscli $error_only $itemtype $action \"$obj\" $*"
            # shellcheck disable=SC2086
            if ! cscli $error_only "$itemtype" "$action" "$obj" "$@"; then
                echo "Failed to $action $itemtype/$obj, running hub update before retrying"
                run_hub_update
                # shellcheck disable=SC2086
                cscli $error_only "$itemtype" "$action" "$obj" "$@"
            fi
        fi
    done
}

# Output the difference between two lists
# of items separated by spaces
difference() {
  list1="$1"
  list2="$2"

  # split into words
  # shellcheck disable=SC2086
  set -- $list1
  for item in "$@"; do
    found=false
    for i in $list2; do
      if [ "$item" = "$i" ]; then
        found=true
        break
      fi
    done
    if [ "$found" = false ]; then
      echo "$item"
    fi
  done
}

#-----------------------------------#

if [ -n "$CERT_FILE" ] || [ -n "$KEY_FILE" ] ; then
    printf '%b' '\033[0;33m'
    echo "Warning: the variables CERT_FILE and KEY_FILE have been deprecated." >&2
    echo "Please use LAPI_CERT_FILE and LAPI_KEY_FILE insted." >&2
    echo "The old variables will be removed in a future release." >&2
    printf '%b' '\033[0m'
    export LAPI_CERT_FILE=${LAPI_CERT_FILE:-$CERT_FILE}
    export LAPI_KEY_FILE=${LAPI_KEY_FILE:-$KEY_FILE}
fi

# Check and prestage /etc/crowdsec
if [ ! -e "/etc/crowdsec/local_api_credentials.yaml" ] && [ ! -e "/etc/crowdsec/config.yaml" ]; then
    echo "Populating configuration directory..."
    # don't overwrite existing configuration files, which may come
    # from bind-mount or even be read-only (configmaps)
    if [ -e /staging/etc/crowdsec ]; then
        mkdir -p /etc/crowdsec/
        # if you change this, check that it still works
        # under alpine and k8s, with and without tls
        rsync -av --ignore-existing /staging/etc/crowdsec/* /etc/crowdsec
    fi
fi

# do this as soon as we have a config.yaml, to avoid useless warnings
if istrue "$USE_WAL"; then
    conf_set '.db_config.use_wal = true'
elif [ -n "$USE_WAL" ] && isfalse "$USE_WAL"; then
    conf_set '.db_config.use_wal = false'
fi

lapi_credentials_path=$(conf_get '.api.client.credentials_path')

# generate local agent credentials (even if agent is disabled, cscli needs a
# connection to the API)
if ( isfalse "$USE_TLS" || [ "$CLIENT_CERT_FILE" = "" ] ); then
    ## We have 2 possibilities here:
    ## - LAPI creds are stored in a secret then copied to /etc/crowdsec/local_api_credentials.yaml or /etc/crowdsec/ is persistent. If so, we check if the machine is registered, and register it if not.
    ## - LAPI creds are not stored in a secret (1st run with persistent volume, or any run without secret). In this case we check if the machine is registered, and register it if not.
    echo "Check if local agent needs to be registered"

    lapi_login=$(yq e '.login' "$lapi_credentials_path" 2>/dev/null || echo "")
    lapi_password=$(yq e '.password' "$lapi_credentials_path" 2>/dev/null || echo "")

    if [ "$lapi_login" = "" ] || [ "$lapi_password" = "" ] ; then
    # Nothing found, probably first run with persistent volume or without secret
        echo "Generate local agent credentials"
        cscli machines add "$CUSTOM_HOSTNAME" --auto --force
    else
        echo "Local agent credentials found"
        if ( cscli machines list -o json | yq -e 'any_c(.machineId==strenv(CUSTOM_HOSTNAME))' >/dev/null ); then
            echo "Local agent already registered"
        else
            echo "Registering local agent to lapi from existing credentials"
            # || true to avoid failing if already registered, as if multiple LAPIs replica are running, they will all try to register at the same time
            cscli machines add "$lapi_login" -p "$lapi_password" -f /dev/null --force || true
        fi
    fi
fi

# ----------------

conf_set_if "$LOCAL_API_URL" '.url = strenv(LOCAL_API_URL)' "$lapi_credentials_path"

conf_set_if "$INSECURE_SKIP_VERIFY" '.api.client.insecure_skip_verify = env(INSECURE_SKIP_VERIFY)'

# agent-only containers still require USE_TLS
if istrue "$USE_TLS"; then
    # shellcheck disable=SC2153
    conf_set_if "$CACERT_FILE" '.ca_cert_path = strenv(CACERT_FILE)' "$lapi_credentials_path"
    conf_set_if "$CLIENT_KEY_FILE" '.key_path = strenv(CLIENT_KEY_FILE)' "$lapi_credentials_path"
    conf_set_if "$CLIENT_CERT_FILE" '.cert_path = strenv(CLIENT_CERT_FILE)' "$lapi_credentials_path"
else
    conf_set '
        del(.ca_cert_path) |
        del(.key_path) |
        del(.cert_path)
    ' "$lapi_credentials_path"
fi

if istrue "$DISABLE_ONLINE_API"; then
    conf_set 'del(.api.server.online_client)'
fi

if isfalse "$DISABLE_ONLINE_API" ; then
    CONFIG_DIR=$(conf_get '.config_paths.config_dir')
    export CONFIG_DIR
    config_exists=$(conf_get '.api.server.online_client | has("credentials_path")')
    if isfalse "$config_exists"; then
        # no CAPI config in the pod (either 1st run with volume, or any run with CAPI creds stored in secrets)
        # check if we have a login in online_api_credentials.yaml
        # if we don't, register to the online API
        conf_set '.api.server.online_client = {"credentials_path": strenv(CONFIG_DIR) + "/online_api_credentials.yaml"}'
        has_login=$(conf_get ".login"  "$CONFIG_DIR/online_api_credentials.yaml")
        if [ "$has_login" = "null" ] || [ -z "$has_login" ]; then
            echo "Registering to online API"
            cscli capi register
            echo "Registration to online API done"
        fi
    fi
fi

# Enroll instance if enroll key is provided
if isfalse "$DISABLE_ONLINE_API" && [ "$ENROLL_KEY" != "" ]; then
    enroll_args=""
    if [ "$ENROLL_INSTANCE_NAME" != "" ]; then
        enroll_args="--name $ENROLL_INSTANCE_NAME"
    fi
    if [ "$ENROLL_TAGS" != "" ]; then
        # shellcheck disable=SC2086
        for tag in ${ENROLL_TAGS}; do
            enroll_args="$enroll_args --tags $tag"
        done
    fi
    # shellcheck disable=SC2086
    cscli console enroll $enroll_args "$ENROLL_KEY"
fi

# crowdsec sqlite database permissions
if [ "$GID" != "" ]; then
    if istrue "$(conf_get '.db_config.type == "sqlite"')"; then
        # force the creation of the db file(s)
        cscli machines inspect create-db --error >/dev/null 2>&1 || :
        # don't fail if the db is not there yet
        if chown -f ":$GID" "$(conf_get '.db_config.db_path')" 2>/dev/null; then
            echo "sqlite database permissions updated"
        fi
    fi
fi

if istrue "$USE_TLS"; then
    agents_allowed_yaml=$(csv2yaml "$AGENTS_ALLOWED_OU")
    export agents_allowed_yaml
    bouncers_allowed_yaml=$(csv2yaml "$BOUNCERS_ALLOWED_OU")
    export bouncers_allowed_yaml
    conf_set_if "$CACERT_FILE" '.api.server.tls.ca_cert_path = strenv(CACERT_FILE)'
    conf_set_if "$LAPI_CERT_FILE" '.api.server.tls.cert_file = strenv(LAPI_CERT_FILE)'
    conf_set_if "$LAPI_KEY_FILE" '.api.server.tls.key_file = strenv(LAPI_KEY_FILE)'
    conf_set_if "$BOUNCERS_ALLOWED_OU" '.api.server.tls.bouncers_allowed_ou = env(bouncers_allowed_yaml)'
    conf_set_if "$AGENTS_ALLOWED_OU" '.api.server.tls.agents_allowed_ou = env(agents_allowed_yaml)'
else
    conf_set 'del(.api.server.tls)'
fi

conf_set_if "$PLUGIN_DIR" '.config_paths.plugin_dir = strenv(PLUGIN_DIR)'


## Register bouncers via env
for BOUNCER in $(compgen -A variable | grep -i BOUNCER_KEY); do
    KEY=$(printf '%s' "${!BOUNCER}")
    NAME=$(printf '%s' "$BOUNCER" | cut -d_  -f3-)
    if [[ -n $KEY ]] && [[ -n $NAME ]]; then
        register_bouncer "$NAME" "$KEY"
    fi
done

if [ "$ENABLE_CONSOLE_MANAGEMENT" != "" ]; then
    # shellcheck disable=SC2086
    cscli console enable console_management
fi

## Register bouncers via secrets (Swarm only)
shopt -s nullglob extglob
for BOUNCER in /run/secrets/@(bouncer_key|BOUNCER_KEY)* ; do
    KEY=$(cat "${BOUNCER}")
    NAME=$(echo "${BOUNCER}" | awk -F "/" '{printf $NF}' | cut -d_  -f2-)
    if [[ -n $KEY ]] && [[ -n $NAME ]]; then
        register_bouncer "$NAME" "$KEY"
    fi
done
shopt -u nullglob extglob

# set all options before validating the configuration

conf_set_if "$METRICS_PORT" '.prometheus.listen_port=env(METRICS_PORT)'

ARGS=""
if [ "$CONFIG_FILE" != "" ]; then
    ARGS="-c $CONFIG_FILE"
fi

if istrue "$LEVEL_TRACE"; then
    ARGS="$ARGS -trace"
fi

if istrue "$LEVEL_DEBUG"; then
    ARGS="$ARGS -debug"
fi

if istrue "$LEVEL_INFO"; then
    ARGS="$ARGS -info"
fi

if istrue "$LEVEL_WARN"; then
    ARGS="$ARGS -warning"
fi

if istrue "$LEVEL_ERROR"; then
    ARGS="$ARGS -error"
fi

if istrue "$LEVEL_FATAL"; then
    ARGS="$ARGS -fatal"
fi

# shellcheck disable=SC2086
exec crowdsec $ARGS