# MQTT

Live last-10 messages from a Mosquitto broker, in the Omarchy bar.

The widget subscribes while it is on the bar and keeps a ring buffer of the
ten most recent messages. Mosquitto does not store a queryable history, so
the list is empty until traffic arrives and it clears when the shell restarts.

## Install

```sh
omarchy plugin add git@github.com:TheSameCat2/omarchy-mqtt.git --enable
```

The repo is private until you publish it. After you make it public, the same
command works with the HTTPS URL:

```sh
omarchy plugin add https://github.com/TheSameCat2/omarchy-mqtt.git --enable
```

## Requirements

- `mosquitto_sub` on `PATH` (the `mosquitto` package on Arch)
- A reachable MQTT broker. Defaults to `localhost:1883` with no auth.

## Usage

Click the bar icon to open the panel. Escape closes it.

- **Localhost** connects to `127.0.0.1:1883`
- **Custom** shows address and port fields. A non-default local port is a custom address (`127.0.0.1` + port)
- **Filter topics** is collapsed by default. With no filters the widget subscribes to `#`. Add MQTT topics (wildcards allowed) to subscribe to those instead
- Click a message to copy its payload

## Remove

```sh
omarchy plugin remove thesamecat.mqtt
```
