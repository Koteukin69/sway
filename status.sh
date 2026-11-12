#!/usr/bin/env bash
fifo=$(mktemp -u)
mkfifo "$fifo"
exec 3<>"$fifo"
rm "$fifo"
trap 'kill 0' EXIT

bat() { cat /sys/class/power_supply/BAT*/capacity | head -1; }
wifi() { timeout 3 nmcli -t -f active,ssid,signal,rate dev wifi list --rescan no | awk -F: '/^yes/{print $2" "$3"% "$4}'; }
gw_parse() { while read -r l; do
  case $l in
  *time=*) x=${l##*time=} x=${x%% *} ;;
  *"no answer"*) x= ;;
  *) continue ;;
  esac
  printf 'gw\t%s\n' "$x" >&3
done; }

gw_live() {
  {
    echo
    nmcli monitor
  } | while read -r _; do
    kill "$p" 2>/dev/null
    printf 'gw\t\n' >&3
    ping -O -i 0.2 "$(ip route | awk '/^default/{print $3; exit}')" 2>/dev/null > >(gw_parse) &
    p=$!
  done &
}
vol() {
  local s
  s=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -o '[0-9]*%' | head -1)
  LC_ALL=C pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes && s="$s muted"
  echo "$s"
}
br() { brightnessctl -m | cut -d, -f4; }
lay() { swaymsg -t get_inputs -r | jq -r '[.[]|select(.type=="keyboard")][0].xkb_active_layout_name' | cut -c1-2 | tr A-Z a-z; }
t() { date '+%Y-%m-%d %H:%M:%S'; }

vol_ev() { LC_ALL=C pactl subscribe | grep --line-buffered -E 'on (sink|server) #'; }
br_ev() { udevadm monitor -k -s backlight; }
lay_ev() { swaymsg -t subscribe -m '["input"]'; }
wifi_ev() { nmcli monitor; }

emit() { printf '%s\t%s\n' "$1" "$($1)" >&3; }

poll() { while :; do
  emit "$1"
  sleep "$2"
done & }

watch() { while :; do
  emit "$1"
  "$1_ev" | while read -r _; do emit "$1"; done
  sleep 1
done & }

poll bat 30
watch wifi
poll wifi 10
poll t 1
gw_live
watch vol
watch br
watch lay

declare -A v
while IFS=$'\t' read -r k x <&3; do
  v[$k]=$x
  echo "${v[lay]} | BR ${v[br]} | VOL ${v[vol]} | WIFI ${v[wifi]:-off} | PING ${v[gw]:-----} ms | BAT ${v[bat]}% | ${v[t]}"
done
