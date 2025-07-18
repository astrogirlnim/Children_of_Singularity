# Sound Effects Needed

The following sound effect files should be added to assets/audio/sfx/:

1. pickup_debris.ogg - Played when collecting debris
2. approach_station.ogg - Played when approaching trading hub
3. ui_select.ogg - For UI button clicks (future)

Convert audio files to OGG format using:
ffmpeg -i input.wav -acodec libvorbis -q:a 5 output.ogg
