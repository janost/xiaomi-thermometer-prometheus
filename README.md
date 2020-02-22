# Introduction
This is a quick and dirty script to pull temperature, humidity and battery status from Xiaomi Mijia BLE sensor and write the results into a file which can be picked up by Prometheus node_exporter's textfile collector so the data can be pulled by Prometheus. This script is based on [this project][mplinuxgeek-xiaomi].

# Prerequisites
- A computer, for example an SBC
- A bluetooth controller which is able to communicate through BLE
- `bluez`, `bc`

# How to use
- Open the script, check and edit the variables at the beginning of the file.
- Add your sensors to `/etc/xiaomi-sensors` in the following format: `FF:FF:FF:FF:FF:FF,NickName`. One sensor per line.
- Add a cronjob to run the script as frequently as you want. You probably want to run it as root.
- Run `node_exporter` with `--collector.textfile.directory=/tmp/prom-textfile` (change the path is that's not suitable for you)
- Configure your Prometheus instance to pull data from your `node_exporter` instance.

# Sample output
```
xiaomi_temperature{sensor="LivingRoom",mac="FF:FF:FF:FF:FF:FF"} 22.1
xiaomi_humidity{sensor="LivingRoom",mac="FF:FF:FF:FF:FF:FF"} 44.8
xiaomi_battery{sensor="LivingRoom",mac="FF:FF:FF:FF:FF:FF"} 90
xiaomi_temperature_updated{sensor="LivingRoom",mac="FF:FF:FF:FF:FF:FF"} 1582369745
xiaomi_humidity_updated{sensor="LivingRoom",mac="FF:FF:FF:FF:FF:FF"} 1582369745
xiaomi_battery_updated{sensor="LivingRoom",mac="FF:FF:FF:FF:FF:FF"} 1582369745
```


[mplinuxgeek-xiaomi]: https://github.com/mplinuxgeek/Xiaomi-BLE-Temperature-and-Humidity-sensor