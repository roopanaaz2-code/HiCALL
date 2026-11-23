import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallPreferencesService {
  CallPreferencesService._();

  static const _ringtoneKey = 'hicall.incoming_ringtone_path';
  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  static final AudioPlayer _player = AudioPlayer();

  static Future<String?> ringtonePath() => _preferences.getString(_ringtoneKey);

  static Future<String?> chooseRingtone() async {
    final picked = await FilePicker.pickFile(type: FileType.audio);
    if (picked == null) return null;
    final sourcePath = picked.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw const FormatException('This audio file could not be opened. Choose another file.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FormatException('The selected audio file is no longer available.');
    }
    final size = await source.length();
    if (size == 0 || size > 15 * 1024 * 1024) {
      throw const FormatException('Choose an audio file smaller than 15 MB.');
    }
    final extension = picked.extension?.toLowerCase();
    const allowed = {'mp3', 'm4a', 'aac', 'wav', 'ogg', '3gp', 'amr'};
    if (extension == null || !allowed.contains(extension)) {
      throw const FormatException('Choose MP3, M4A, AAC, WAV, OGG, 3GP or AMR audio.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final destination = File('${directory.path}/hicall_incoming_ringtone.$extension');
    if (await destination.exists()) await destination.delete();
    await source.copy(destination.path);
    await _preferences.setString(_ringtoneKey, destination.path);
    return destination.path;
  }

  static Future<void> playIncomingRingtone() async {
    try {
      final path = await ringtonePath();
      if (path == null || !await File(path).exists()) return;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(DeviceFileSource(path));
    } catch (_) {
      // A ringtone failure must never prevent the incoming-call prompt.
    }
  }

  static Future<void> stopIncomingRingtone() async {
    try {
      await _player.stop();
    } catch (_) {
      // The player may not have been initialized by a selected ringtone.
    }
  }

  static Future<void> clearRingtone() async {
    final path = await ringtonePath();
    await stopIncomingRingtone();
    await _preferences.remove(_ringtoneKey);
    if (path != null && await File(path).exists()) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  static Future<void> previewRingtone() => playIncomingRingtone();
}
