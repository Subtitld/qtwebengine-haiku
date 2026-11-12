#!/bin/sh
# Configure QtWebEngine for Haiku in /build/out: widgets only, offscreen
# software rendering is all Subtitld needs, so everything optional is off.
mkdir -p /build/out && cd /build/out && rm -rf CMakeCache.txt CMakeFiles
export NINJAFLAGS="-j3 -k 0"
cmake -G Ninja /build/src/qtwebengine-everywhere-src-6.10.3 \
  -DCMAKE_PREFIX_PATH=/boot/system \
  -DCMAKE_INSTALL_PREFIX=/build/install \
  -DPython3_EXECUTABLE=/boot/system/bin/python3.10 \
  -DQT_FEATURE_qtpdf_build=OFF \
  -DQT_FEATURE_qtwebengine_quick_build=OFF \
  -DQT_FEATURE_webengine_printing_and_pdf=OFF \
  -DQT_FEATURE_webengine_pepper_plugins=OFF \
  -DQT_FEATURE_webengine_spellchecker=OFF \
  -DQT_FEATURE_webengine_webrtc=OFF \
  -DQT_FEATURE_webengine_geolocation=OFF \
  -DQT_FEATURE_webengine_proprietary_codecs=OFF \
  -DQT_FEATURE_webengine_kerberos=OFF \
  -DQT_FEATURE_webengine_extensions=OFF \
  -DQT_FEATURE_webengine_vulkan=OFF \
  -DQT_FEATURE_webengine_vaapi=OFF \
  -DQT_FEATURE_webenginedriver=OFF \
  -DQT_FEATURE_webengine_system_ffmpeg=ON \
  -DQT_FEATURE_webengine_system_alsa=OFF \
  -DQT_FEATURE_webengine_system_pulseaudio=OFF \
  -DQT_FEATURE_webengine_system_sndio=OFF \
  -DQT_FEATURE_webengine_system_gbm=OFF \
  -DQT_FEATURE_webengine_ozone_x11=OFF \
  -DQT_FEATURE_webengine_jumbo_build=OFF \
  "$@" > conf.log 2>&1
status=$?
echo "exit $status" >> conf.log
exit $status
