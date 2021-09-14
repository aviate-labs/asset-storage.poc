#!/usr/bin/env sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

bold() {
    tput bold
    echo $1
    tput sgr0
}

check() {
    bold "| $1: \c"
    if [ "$2" = "$3" ]; then
        echo "${GREEN}OK${NC}"
    else
        echo "${RED}NOK${NC}: expected ${3}, got ${2}"
        dfx -q stop > /dev/null 2>&1
        exit 1
    fi
}

bold "| Starting replica."
dfx start --background --clean > /dev/null 2>&1

dfx identity new admin > /dev/null 2>&1
dfx -q identity use admin
adminID=$(dfx identity get-principal)
dfx identity new user > /dev/null 2>&1
dfx -q identity use user
userID=$(dfx identity get-principal)

dfx -q identity use default
dfx -q deploy full-example --no-wallet
check "Check if owner is autherized" \
      "$(dfx canister call full-example clear "(record {})")" \
      "()"

dfx -q identity use user
check "Check if user is not autherized" \
      "$(dfx canister call full-example clear "(record {})")" \
      ""

dfx -q identity use default
check "Autherize admin" \
      "$(dfx canister call full-example authorize "(principal \"$adminID\")")" \
      "()"

dfx -q identity use admin
check "Check if admin is autherized" \
      "$(dfx canister call full-example clear "(record {})")" \
      "()"

# dfx stop > /dev/null 2>&1
