#!bin/bash

ps aux | grep 'ssh -nNTf -i' | awk '{print $2}' | xargs kill -9
ps aux | grep 'cardano-tracer' | awk '{print $2}' | xargs kill -9

