import 'dart:io';

/// Reads an environment variable from [Platform.environment], falling back to a
/// local `.env` file in the current working directory if present.
String? readEnvVar(
  String name, {
  File? envFile,
  Map<String, String>? environment,
}) {
  final env = environment ?? Platform.environment;
  final fromProcess = env[name]?.trim();
  if (fromProcess != null && fromProcess.isNotEmpty) {
    return fromProcess;
  }

  final file = envFile ?? File('.env');
  if (!file.existsSync()) {
    return null;
  }

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final separatorIndex = line.indexOf('=');
    if (separatorIndex <= 0) continue;

    final key = line.substring(0, separatorIndex).trim();
    if (key != name) continue;

    var value = line.substring(separatorIndex + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    return value.isEmpty ? null : value;
  }

  return null;
}

/// Returns `GEMINI_API_KEY` from the environment (or local `.env`).
String? readGeminiApiKey({File? envFile}) =>
    readEnvVar('GEMINI_API_KEY', envFile: envFile);
