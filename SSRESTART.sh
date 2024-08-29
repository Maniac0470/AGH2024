#!/bin/bash

pid=$(ps aux | grep -i indicator | grep -v grep | awk '{print $2}')
kill ${pid}
/usr/bin/indicator-sound-switcher&
