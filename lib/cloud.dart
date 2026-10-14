import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore'до маалымат users/{uid}/chunks/{i} документтеринде сакталат.
/// Бир документ 1 MiB'дан ашпашы үчүн JSON бөлүктөргө бөлүнөт.
const _chunkChars = 300000;

Future<void> cloudSave(String uid, String json) async {
  final root = FirebaseFirestore.instance.collection('users').doc(uid);
  final parts = <String>[];
  var start = 0;
  while (start < json.length) {
    var end = start + _chunkChars;
    if (end >= json.length) {
      end = json.length;
    } else if (_isHighSurrogate(json.codeUnitAt(end - 1))) {
      // Эмоджинин жупу бөлүнүп кетпеши үчүн
      end -= 1;
    }
    parts.add(json.substring(start, end));
    start = end;
  }
  final batch = FirebaseFirestore.instance.batch();
  for (var i = 0; i < parts.length; i++) {
    batch.set(root.collection('chunks').doc('$i'), {'data': parts[i]});
  }
  batch.set(root, {'count': parts.length, 'updatedAt': DateTime.now().toUtc().toIso8601String()}, SetOptions(merge: true));
  await batch.commit();
}

Future<String?> cloudLoad(String uid) async {
  final root = FirebaseFirestore.instance.collection('users').doc(uid);
  final meta = await root.get();
  if (!meta.exists) return null;
  final count = (meta.data()?['count'] as num?)?.toInt() ?? 0;
  final buf = StringBuffer();
  for (var i = 0; i < count; i++) {
    final chunk = await root.collection('chunks').doc('$i').get();
    buf.write(chunk.data()?['data'] ?? '');
  }
  return buf.toString();
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
