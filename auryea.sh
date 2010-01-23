#!/bin/bash

setenv () {
  if [[ -z "${!1}" ]]; then
    read -r $1 <<< "$2"
    export $1
  fi
}

setenv MAKEPKG_OPTS "-i"
setenv AURYEA_WRAP_PACMAN 1
setenv AURYEA_PACMAN_SEARCH 1
setenv AURYEA_USE_SHELL 1
setenv AURYEA_SHELL_NOPROFILE 1
setenv AURYEA_TMP_DIRECTORY "/tmp/auryea-${USER}"
setenv AURYEA_PARSE_DEPENDS 1
setenv AURYEA_NO_REINSTALL 0
setenv AURYEA_VERBOSE_INSTALL 1
setenv AURYEA_COMPACT_SEARCH 0

setenv AURYEA_COLOR_ENABLE 1
setenv AURYEA_COLOR_PACKAGE "\033[1m"
setenv AURYEA_COLOR_CATEGORY "\033[1;35m"
setenv AURYEA_COLOR_VERSION "\033[1;32m"
setenv AURYEA_COLOR_WARNING "\033[1;31m"
setenv AURYEA_COLOR_ERROR "\033[0;31m"

BASEURL="http://aur.archlinux.org"
RPCURL="${BASEURL}/rpc.php"
CATEGORIES=(
  [1]='none'
  [2]='daemons'
  [3]='devel'
  [4]='editors'
  [5]='emulators'
  [6]='games'
  [7]='gnome'
  [8]='i18n'
  [9]='kde'
  [10]='lib'
  [11]='modules'
  [12]='multimedia'
  [13]='network'
  [14]='office'
  [15]='science'
  [16]='system'
  [17]='x11'
  [18]='xfce'
  [19]='kernels'
)

error () {
  echo -e "${AURYEA_COLOR_ERROR}error:\033[0m $*" >&2
}

warning () {
  echo -e "${AURYEA_COLOR_WARNING}warning:\033[0m $*" >&2
}

sigint () {
  echo
  error "user aborted"
  exit 1
}

if [[ $UID == 0 ]]; then
  warning "running as root can kill kittens"
  MAKEPKG_OPTS="${MAKEPKG_OPTS} --asroot"
fi

color () {
  if [[ $AURYEA_COLOR_ENABLE == 1 ]]; then
    case "$1" in
      pkg|package)
        echo -ne "${AURYEA_COLOR_PACKAGE}"
        ;;
      ver|version)
        echo -ne "${AURYEA_COLOR_VERSION}"
        ;;
      cat|category)
        echo -ne "${AURYEA_COLOR_CATEGORY}"
        ;;
    esac
    local e="\033[0m"
  fi
  echo -ne "${2}${e}"
}

usage () {
  if [[ $AURYEA_WRAP_PACMAN == 1 ]]; then
    pacman --help "$@" | sed 's/pacman/auryea/'
  else
    echo "usage: exactly like you would pacman."
  fi
  exit 0
}

version () {
  echo "auryea v0.5"
  echo "Copyright (c) 2009 David 'dav' Gidwani"
  echo
  echo "This program is free software: you can redistribute it and/or modify"
  echo "it under the terms of the GNU General Public License as published by"
  echo "the Free Software Foundation, either version 3 of the License, or"
  echo "(at your option) any later version."
  exit 0
}

gk () {
  local t1="${1#*${2}\":\"}"
  echo "${t1%%\"*}"
}

sudo () {
  if [[ $UID == 0 ]]; then
    "$@"
    return $?
  fi
  if builtin type -P sudo &> /dev/null; then
    command sudo $@
  else
    su -c $@
  fi
  return $?
}

pacman () {
  if builtin type -P pacman-color &> /dev/null; then
    pacman-color $@
  else
    pacman $@
  fi
}

print_pkg () {
  mapfile -t arr <<< "$1"
  for ((i=0; i<"${#arr[@]}"; i++)); do
    local category="${CATEGORIES[$(gk "${arr[$i]}" CategoryID)]}"
    local name="$(gk "${arr[$i]}" Name)"
    # TODO: permanent fix for JSON collections that span multiple lines
    # f.ex, see the output of http://aur.archlinux.org/rpc.php?type=search&arg=goggles
    [[ -z $name || -z $category ]] && continue
    echo -en "$(color cat $category)/$(color pkg $name) $(color ver $(gk "${arr[$i]}" Version))"
    if [[ $ACTION == "search" && $AURYEA_COMPACT_SEARCH != 1 || $ACTION == "sync" ]]; then
      echo
      echo -e "$(gk "${arr[$i]}" Description | fold -s | sed 's/\(.*\)/    \1/')"
    fi
  done
}

shell () {
  if [[ $AURYEA_USE_SHELL == 1 ]]; then
    read -n1 -p "${1:-drop into a shell? [Y/n]}"
    echo
    if [[ $REPLY == [Yy] ]]; then
      echo "remember to exit once you're done!"
      if [[ $AURYEA_SHELL_NOPROFILE == 1 ]]; then
        case "$(basename $SHELL)" in
          zsh)
            (export PS1='[%1~]> '; $SHELL -f)
            ;;
          bash)
            (export PS1='[\W]> '; $SHELL --noprofile --norc)
            ;;
          *)
            $SHELL
            ;;
        esac
      else
        $SHELL
      fi
    fi
  fi
}

clean () {
  case "$1" in
    outdated)
      local d pkgs v1 v2 vc
      echo "cache directory: ${AURYEA_TMP_DIRECTORY}"
      read -n1 -p "really remove outdated packages? [Y/n] "
      echo
      if [[ $REPLY == [yY] ]]; then
        for p in ${AURYEA_TMP_DIRECTORY}/*; do
          [[ ! -d "$p/${p##*/}" ]] && { d=1; continue; }
          v1=$(pacman -Q "${p##*/}" 2> /dev/null)
          cd "$p/${p##*/}"
          pkgs=$(ls *.pkg.tar.gz 2> /dev/null)
          if [[ $? == 0 ]]; then
            for f in "$pkgs"; do
              tar xf "$f" .PKGINFO 2> /dev/null
              [[ $? -gt 0 ]] && continue
              v2=$(grep pkgver .PKGINFO)
              vc=$(vercmp "${v1##* }" "${v2##*= }")
              [[ $vc -ge 0 ]] && d=1
            done
          else
            d=1
          fi
          [[ $d == 1 ]] && rm -rf "$p"
        done
      fi
      [[ $AURYEA_WRAP_PACMAN == 1 ]] && sudo pacman -Sc
      ;;
    all)
      echo "cache directory: ${AURYEA_TMP_DIRECTORY}"
      read -n1 -p "really really REALLY rm -rf it? cannot be undone, kills kittens, etc etc"
      echo
      if [[ $REPLY == [yY] ]]; then
        rm -rf "${AURYEA_TMP_DIRECTORY}"
      fi
      [[ $AURYEA_WRAP_PACMAN == 1 ]] && sudo pacman -Scc
      ;;
  esac
}

search () {
  local r rv
  echo -n "searching AUR..."
  r=$(aur search "$1")
  rv=$?
  case "$rv" in
    10)
      error "invalid operation"
      return $rv
      ;;
    9)
      echo -ne "\r"
      error "$r"
      return $rv
      ;;
    [1-8])
      echo -e "\rwget failed. see \`man wget'" >&2
      return $rv
      ;;
    0)
      echo
      print_pkg "$r"
      [[ $AURYEA_PACMAN_SEARCH == 1 ]] && pacman -Ss "$1"
      ;;
  esac
}

upgrade () {
  local rv ip ap pv lv vc
  if [[ $ACTION != "sync" ]]; then
    error "invalid/no operation specified"
    exit 1
  fi
  if [[ $AURYEA_WRAP_PACMAN == 1 ]]; then
    shift
    sudo pacman -Su $ao ${@:2:$#}
    rv=$?
    if [[ $rv -gt 0 ]]; then
      local rv=$?
      read -n1 -p "pacman borked. really attempt to upgrade AUR packages? (!recommended) [Y/n]"
      [[ $REPLY != [Yy] ]] && exit $rv
    fi
  fi
  echo "checking AUR for updates...this could take a while"
  IFS=$'\n'
  ap=( )
  for p in $(pacman -Qme); do
    ip="$(aur info ${p%% *})"
    [[ $? -gt 0 ]] && continue
    lv="${p##* }"
    pv=$(gk "$ip" Version)
    vc=$(vercmp $lv $pv)
    if [[ $vc == 0 ]]; then
      continue
    elif [[ $vc == 1 ]]; then
      warning "$(color pkg $p): local ($(color ver $lv)) is newer than AUR ($(color ver $pv))"
    else
      echo -en " * $(color cat ${CATEGORIES[$(gk "$ip" CategoryID)]})"
      echo -e "/$(color pkg ${p%% *}) ($(color ver $lv) -> $(color ver $pv))"
      ap+=( "${p%% *}" "$pv" "$(gk "$ip" URLPath)")
    fi
  done
  unset IFS
  read -n1 -p "upgrade these packages? [Y/n] "
  [[ $REPLY != [Yy] ]] && exit
  echo
  for ((i=0; i<${#ap[@]}; i=i+3)); do
    install "${ap[$i]}" "${ap[$((i+2))]}"
  done
  unset ip ap v2 vc
}

install () {
  local i o r
  r=$(aur info "$1")
  if [[ $? == 9 && $AURYEA_WRAP_PACMAN == 1 ]]; then
    error "couldn't find package '${1}' in AUR, falling back to pacman"
    sudo pacman -S "$1"
    exit $?
  fi
  i=$(pacman -Q "$1" 2> /dev/null)
  if [[ $? != 0 ]]; then
    echo "syncing \`$p'..."
  else
    local v1 v2 vc
    v1=${i##* }
    v2=$(gk "$r" Version)
    vc=$(vercmp $v1 $v2)
    if [[ $vc == 0 && $AURYEA_NO_REINSTALL != 1 ]]; then
      warning "$(color pkg $i) is up to date -- reinstalling"
    elif [[ $vc == 0 && $AURYEA_NO_REINSTALL == 1 ]]; then
      return
    elif [[ $vc -gt 0 ]]; then
      warning "$(color pkg $i) ($(color ver $v1)) is newer than AUR ($(color ver $v2))"
    elif [[ $vc -lt 0 ]]; then
      echo "upgrading: $(color pkg $i) $(color ver $v1) -> $(color ver $v2)"
    fi
  fi
  if [[ $AURYEA_VERBOSE_INSTALL == 1 ]]; then
    print_pkg "$r"
  fi
  local n=$(gk "$r" Name)
  local u=$(gk "$r" URLPath)
  mkdir -p "$AURYEA_TMP_DIRECTORY/$n" &> /dev/null
  if [[ $? -gt 0 ]]; then
    error "unable to create temp directory"
    exit 1
  fi
  cd "$AURYEA_TMP_DIRECTORY/$n"
  wget -nc "${BASEURL}/${u//\\}" 2>/dev/null
  if [[ $? -gt 0 ]]; then
    error "wget borked (returned ${?})!"
    return 1
  fi
  local x="${u##*/}"
  tar xzf "$x"
  cd "${x%%.*}"
  shell "drop into $(basename $SHELL) @ $PWD? [Y/n] "
  if [[ $AURYEA_PARSE_DEPENDS == 1 ]]; then
    unset depends
    . PKGBUILD
    if [[ "${#depends[@]}" -gt 0 ]]; then
      echo "parsing dependencies..."
      for p in "${depends[@]}"; do
        if ! pacman -T "$p" &> /dev/null; then
          echo -n "resolving dependency: $p"
          if pacman -Si "${p%%[<>=]*}" &> /dev/null; then
            echo " (pacman)"
            sudo pacman -S "$p"
          else
            echo " (auryea)"
            AURYEA_NO_REINSTALL=1 install "$p"
          fi
        fi
      done
    fi
  fi
  makepkg $MAKEPKG_OPTS
  if [[ $? -gt 0 ]]; then
    error "makepkg failed - abort! abort!"
    shell "drop into $(basename $SHELL) again for troubleshooting? [Y/n] "
    # TODO: prompt and attempt to rebuild the package
    exit 1
  else
    echo "installed package \`${1}' at $(date)"
  fi
}

aur () {
  o="$(wget -q -O- "${RPCURL}?type=${1}&arg=${2}")"
  [[ $? -gt 0 ]] && return $?
  if [[ $(gk "$o" "type") == 'error' ]]; then
    # error "$(gk "$o" "results")"
    echo "$(gk "$o" "results")"
    return 9
  fi
  case "$1" in
    search|msearch)
      egrep -o "\"results\":\[\{.*\}\]" <<< "$o" | egrep -o '("[^"]+":"[^"]+",?)+'
      ;;
    info)
      egrep -o "\"results\":\{.*\}" <<< "$o" | cut -b12-
      ;;
  esac
}

main () {
  local so lo
  [[ -z "$1" ]] && usage
  so="VQRSUcdeghiklmo:p:s:tuqvr:b:nfwy"
  lo="changelog,deps,explicit,groups,info,check,list,foreign,owns:,file:,search:,\
  unrequired,upgrades,quiet,config:,logfile:,noconfirm,noprogressbar,noscriptlet,\
  verbose,debug,root:,dbpath:,cachedir:,asdeps,asexplicit,clean,nodeps,force,\
  print-uris,sysupgrade,downloadonly,refresh,needed,ignore:,ignoregroup:,cascade,\
  dbonly,nosave,recursive,unneeded,help,version"
  if grep -q 'S' <<< "$@"; then
    lo=$(sed 's/list/list:/' <<< "$lo")
  elif grep -q 'R' <<< "$@"; then
    so=$(sed 's/s:/s/' <<< "$so")
  fi
  set -- $(getopt -u -n$(basename $0) -o"$so" -l"$lo" -- "$@")
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -V|--version)
        [[ $AURYEA_WRAP_PACMAN == 1 ]] && pacman --version; echo -e '---\n'
        version
        exit
        ;;
      -Q|--query)
        [[ -n $ACTION ]] && error "only one operation may be used at a time"
        ACTION=query
        UNHANDLED+="$1 "
        ;;
      -R|--remove)
        [[ $ACTION ]] && error "only one operation may be used at a time"
        ACTION=remove
        UNHANDLED+="$1 "
        ;;
      -U|--upgrade)
        [[ $ACTION ]] && error "only one operation may be used at a time"
        ACTION=upgrade
        UNHANDLED+="$1 "
        ;;
      -S|--sync)
        [[ $ACTION ]] && error "only one operation may be used at a time"
        ACTION=sync
        ;;
      -c|--clean)
        if [[ -n $CLEAN ]]; then
          CLEAN=all
        else
          CLEAN=outdated
        fi
        ;;
      -s|--search)
        SUBACTION=search
        TARGET="$2"
        ;;
      -u|--sysupgrade)
        SUBACTION=upgrade
        ;;
      -h|--help)
        SUBACTION=help
        ;;
      --)
        shift
        case "$ACTION" in
          sync)
            [[ -n $CLEAN ]] && clean "$CLEAN"
            case "$SUBACTION" in
              '')
                [[ -z "$@" ]] && error "no targets specified (use -h for help)"
                for p in "$@"; do
                  install "$p"
                done
                ;;
              search)
                search "$TARGET"
                ;;
              upgrade)
                upgrade
                ;;
              help)
                # TODO: actually display the help for different actions...
                usage
                ;;
            esac
            ;;
          query)
            [[ $AURYEA_WRAP_PACMAN -ne 1 ]] && return
            case "$SUBACTION" in
              '')
                pacman $UNHANDLED $@
                ;;
              search)
                pacman $UNHANDLED -s "$TARGET" $@
                ;;
            esac
            ;;
          '')
            case "$SUBACTION" in
              help)
                usage $UNHANDLED $@
                exit
                ;;
            esac
            usage
            ;;
          *)
            if [[ $AURYEA_WRAP_PACMAN == 1 ]]; then
              if grep -q '\-R' <<< "$UNHANDLED"; then
                sudo pacman $UNHANDLED $@
              else
                pacman $UNHANDLED $@
              fi
            fi
            # TODO: handle replacing packages
            ;;
        esac
        break
        ;;
      -*)
        UNHANDLED+="$1 "
        ;;
    esac
    shift
  done
}

trap sigint SIGINT
main "$@"