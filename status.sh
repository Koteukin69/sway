#!/bin/sh
while :; do
  bat=$(cat /sys/class/power_supply/BAT*/capacity | head -1)
  wifi=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
  vol=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -o '[0-9]*%' | head -1)
  br=$(brightnessctl -m | cut -d, -f4)
  lay=$(swaymsg -t get_inputs -r | jq -r '[.[]|select(.type=="keyboard")][0].xkb_active_layout_name' | cut -c1-2 | tr A-Z a-z)
  t=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$lay | BR $br | VOL $vol | WIFI ${wifi:-off} | BAT $bat% | $t"
  sleep 0.2
done
