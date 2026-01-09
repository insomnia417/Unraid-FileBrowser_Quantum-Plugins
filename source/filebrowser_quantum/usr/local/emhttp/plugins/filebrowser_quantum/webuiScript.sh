#!/bin/bash
if [ "${1}" == "true" ]; then
  echo "Enabling filebrowser_quantum WebUI, please wait..."
  sed -i "/WEBUI_ENABLED=/c\WEBUI_ENABLED=${1}" "/boot/config/plugins/filebrowser_quantum/settings.cfg"
  if pgrep -f "filebrowser_quantum-orig.*--rc-web-gui" > /dev/null 2>&1 ; then
    echo
    echo "filebrowser_quantum WebUI already started!"
    exit 0
  fi
elif [ "${1}" == "false" ]; then
  KILL_PID="$(pgrep -f "filebrowser_quantum-orig.*--rc-web-gui")"
  echo "Disabling filebrowser_quantum WebUI, please wait..."
  kill -SIGINT $KILL_PID
  sed -i "/WEBUI_ENABLED=/c\WEBUI_ENABLED=${1}" "/boot/config/plugins/filebrowser_quantum/settings.cfg"
  echo "filebrowser_quantum WebUI disabled"
  exit 0
elif [ "${1}" == "VERSION" ]; then
  if [ ! -d /boot/config/plugins/filebrowser_quantum/webui ]; then
    mkdir -p /boot/config/plugins/filebrowser_quantum/webui
  fi
  if [ -f /boot/config/plugins/filebrowser_quantum/webui/latest ]; then
    rm -f /boot/config/plugins/filebrowser_quantum/webui/latest
  fi
  API_RESULT="$(wget -qO- https://api.github.com/repos/filebrowser_quantum/filebrowser_quantum-webui-react/releases/latest)"
  echo "${API_RESULT}" | jq -r '.tag_name' | sed 's/^v//' > /boot/config/plugins/filebrowser_quantum/webui/latest
  echo "${API_RESULT}" | jq -r '.assets[].browser_download_url' >> /boot/config/plugins/filebrowser_quantum/webui/latest
  LAT_V="$(cat /boot/config/plugins/filebrowser_quantum/webui/latest | head -1)"
  if [ -z "${LAT_V}" ] || [ "${LAT_V}" == "null" ]; then
    rm -f /boot/config/plugins/filebrowser_quantum/webui/latest
  else
    exit 0
  fi
else
  echo "Error"
  exit 1
fi

echo "Executing version check"
if [ ! -f /boot/config/plugins/filebrowser_quantum/webui/latest ]; then
  API_RESULT="$(wget -qO- https://api.github.com/repos/filebrowser_quantum/filebrowser_quantum-webui-react/releases/latest)"
  echo "${API_RESULT}" | jq -r '.tag_name' | sed 's/^v//' > /boot/config/plugins/filebrowser_quantum/webui/latest
  echo "${API_RESULT}" | jq -r '.assets[].browser_download_url' >> /boot/config/plugins/filebrowser_quantum/webui/latest
  LAT_V="$(cat /boot/config/plugins/filebrowser_quantum/webui/latest | head -1)"
  DL_URL="$(cat /boot/config/plugins/filebrowser_quantum/webui/latest | head -2 | tail -1)"
  CUR_V="$(ls -1 /boot/config/plugins/filebrowser_quantum/webui/*.zip 2>/dev/null | rev | cut -d '/' -f1 | cut -d '.' -f2- | rev | sort -V | head -1 | sed 's/^v//')"
  if [ -z "${LAT_V}" ] || [ "${LAT_V}" == "null" ]; then
    rm -f /boot/config/plugins/filebrowser_quantum/webui/latest
    if [ -z "${CUR_V}" ]; then
      echo "ERROR: Can't get latest version and no current version from filebrowser_quantum webgui installed"
      exit 1
    else
      echo "Can't get latest version from filebrowser_quantum webgui, falling back to installed version: ${CUR_V}"
      LAT_V="${CUR_V}"
    fi
  fi
else
  LAT_V="$(cat /boot/config/plugins/filebrowser_quantum/webui/latest | head -1)"
  DL_URL="$(cat /boot/config/plugins/filebrowser_quantum/webui/latest | head -2 | tail -1)"
  CUR_V="$(ls -1 /boot/config/plugins/filebrowser_quantum/webui/*.zip 2>/dev/null | rev | cut -d '/' -f1 | cut -d '.' -f2- | rev | sort -V | head -1 | sed 's/^v//')"
fi

if [ ! -d /root/.cache/filebrowser_quantum/webui ]; then
  mkdir -p /root/.cache/filebrowser_quantum/webui
fi

if [ -z "$CUR_V" ]; then
  echo "filebrowser_quantum WebUI not installed, downloading..."
  if ! wget -q -O /boot/config/plugins/filebrowser_quantum/webui/${LAT_V}.zip "${DL_URL}" ; then
    echo "Download failed!"
    rm -f /boot/config/plugins/filebrowser_quantum/webui/${LAT_V}.zip
    exit 1
  fi
  unzip -qq /boot/config/plugins/filebrowser_quantum/webui/${LAT_V}.zip -d /root/.cache/filebrowser_quantum/webui
elif [ "$CUR_V" != "$LAT_V" ]; then
  echo "Newer filebrowser_quantum WebUI version found, downloading..."
  if [ -d /root/.cache/filebrowser_quantum/webui/build ]; then
    rm -rf /root/.cache/filebrowser_quantum/webui/build
  fi
  if ! wget -q -O /boot/config/plugins/filebrowser_quantum/webui/${LAT_V}.zip "${DL_URL}" ; then
    echo "filebrowser_quantum WebUI ownload failed!"
    LAT_V="${CUR_V}"
    rm -f /boot/config/plugins/filebrowser_quantum/webui/${LAT_V}.zip
    EXIT_STATUS=1
  fi
  if [ "${EXIT_STATUS}" != 1 ]; then
    unzip -qq /boot/config/plugins/filebrowser_quantum/webui/${LAT_V}.zip -d /root/.cache/filebrowser_quantum/webui
  fi
fi

if [ ! -d /root/.cache/filebrowser_quantum/webui/build ]; then
  unzip -qq /boot/config/plugins/filebrowser_quantum/webui/${LAT_V}.zip -d /root/.cache/filebrowser_quantum/webui
fi

# Remove old versions
rm -f $(ls -1 /boot/config/plugins/filebrowser_quantum/webui/*.zip 2>/dev/null|grep -v "${LAT_V}")

START_PARAMS="$(cat /boot/config/plugins/filebrowser_quantum/settings.cfg | grep -n "^WEBUI_START_PARAMS=" | cut -d '=' -f2- | sed 's/\"//g')"
PORT="$(cat /boot/config/plugins/filebrowser_quantum/settings.cfg | grep -n "^WEBUI_PORT=" | cut -d '=' -f2- | sed 's/\"//g')"

echo "Starting filebrowser_quantum WebUI"
echo "filebrowser_quantum rcd --rc-web-gui --rc-web-gui-no-open-browser --rc-addr=0.0.0.0:${PORT} --rc-files /root/.cache/filebrowser_quantum/webui/build ${START_PARAMS}" | at now -M > /dev/null 2>&1

if pgrep -f "filebrowser_quantum-orig.*--rc-web-gui" > /dev/null 2>&1 ; then
  echo
  echo "filebrowser_quantum WebUI started, you can now connect to the WebUI through Port: ${PORT}"
else
  echo
  echo "filebrowser_quantum WebUI start failed, please check your settings and your logs what went wrong."
fi
