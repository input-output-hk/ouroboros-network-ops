#!/usr/bin/env nix-shell
#!nix-shell -p bash imagemagick zip -i bash

set -x

# Get all server names in "my-network" nixops deployment
servers=( $(nixops info -d my-network --plain | cut -f1) )
declare -p servers

# runInServer server "command"
runInServer() {
  nixops ssh-for-each -d my-network "$2" --include $1;
}

# runInServers "command"
runInServers() {
  nixops ssh-for-each -p -d my-network "$1";
}

# sendToServer server from
sendToServer() {
  nixops scp -d my-network $1 $2 $2 --to;
}

# getFromServer server from
getFromServer() {
  nixops scp -d my-network $1 $2 $2 --from;
}

# getFromServer' server from to
getFromServer2() {
  nixops scp -d my-network $1 $2 $3 --from;
}

# plotScript server file.csv
plotScript() {
  # Get first date
  runInServer $1 "head -n 2 $2 | tail -n 1 | cut -d, -f1" 2> /tmp/$1.tmp
  FIRST_DATE=`tail -n1 /tmp/$1.tmp | cut -d' ' -f2-`

  echo "set title \"$1 Heap Profile\"
set datafile separator \",\"
set terminal png size 800,600 enhanced font \"Arial,12\"
set output \"$1-output.png\"
set grid
set xdata time
set timefmt \"%Y-%m-%d %H:%M:%S UTC\"
set xlabel offset 0,-3,0 font \",10\"
set xlabel sprintf(\"First date: %s\", \"$FIRST_DATE\")
set ylabel sprintf(\"Heap GB\")
plot \"$2\" using 1:2 with lines"
}

# Get all resource log messages
#runInServers "journalctl -u cardano-node -b --no-pager -o json --until \"now\" | jq '. | .MESSAGE | try fromjson | select (.ns == \"Resources\")' > mainnet-resources.json"

# Get all log messages
#runInServers "journalctl -u cardano-node -b --no-pager -o json --since \"2 days ago\" --until \"now\" > mainnet-logs.json"

#Remove all old pngs
rm *.png

TIME=$(date +%s)

# For each server
for server in "${servers[@]}"
do

echo "Processing in $server..."

# Backup resource logs
getFromServer2 "$server" "mainnet-resources.json" "../backup/$TIME-$server-mainnet-resources.json"

# Backup logs
getFromServer2 "$server" "mainnet-logs.json" "../backup/$TIME-$server-mainnet-logs.json"

# Filter all Time and Heap values from resource log messages
runInServer "$server" "cat mainnet-resources.json | jq -r '. | [ (.at[:-6] | strptime(\"%Y-%m-%d %H:%M:%S\") | mktime) , .data.Heap ] | @csv' > $server-heap-mainnet-resources.json.csv"

# Send process script to server
sendToServer "$server" "process-resources.sh"

# Run processing script
runInServer "$server" "echo \"Time(s),Heap(GB)\" > $server-heap-mainnet-resources.json.csv.tmp"
runInServer "$server" "./process-resources.sh $server-heap-mainnet-resources.json.csv >> $server-heap-mainnet-resources.json.csv.tmp"
runInServer "$server" "mv $server-heap-mainnet-resources.json.csv.tmp $server-heap-mainnet-resources.json.csv"
runInServer "$server" "head $server-heap-mainnet-resources.json.csv"

# Create gnuplot script
plotScript "$server" "$server-heap-mainnet-resources.json.csv" > $server-gnuplot.gp

# Send gnuplot script to server
sendToServer "$server" "$server-gnuplot.gp"

# Run gnuplot
runInServer "$server" "nix-shell -p gnuplot --command \"gnuplot $server-gnuplot.gp\""

# Fetch plot result 
getFromServer "$server" "$server-output.png"
done

# Zip backup logs
zip -r $(date +%s)-server-resource-logs-backup.zip ../backup

# Montage all results
montage *.png -tile 2x4 -geometry +0+0 combined.png
