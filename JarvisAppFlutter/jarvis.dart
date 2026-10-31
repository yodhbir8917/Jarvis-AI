import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: JarvisScreen(),
  ));
}

class JarvisScreen extends StatefulWidget {
  const JarvisScreen({super.key});

  @override
  State<JarvisScreen> createState() => _JarvisScreenState();
}

class _JarvisScreenState extends State<JarvisScreen> {
  // Yahan apni Gemini API key dalein
  final String apiKey = "AQ.Ab8RN6LdMnWCst_arNQalmKeo1Rki4IDkUVAK31QG3CIuu-Lyg";

  late final GenerativeModel model;
  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  bool _isListening = false;
  bool _speechEnabled = false;
  String _userText = "Press the mic button or type to begin...";
  String _jarvisResponse = "Online & Ready.";
  String _statusMessage = "Initializing...";
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initTTS();
    _initGemini();
    _initSpeech();
  }

  void _initTTS() {
    _tts = FlutterTts();
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
  }

  void _initGemini() {
    try {
      model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: apiKey,
      );
    } catch (e) {
      setState(() {
        _statusMessage = "Gemini Init Failed: $e";
      });
    }
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          setState(() {
            _statusMessage = "Status: $status";
            if (status == 'notListening' || status == 'done') {
              _isListening = false;
            }
          });
        },
        onError: (errorNotification) {
          setState(() {
            _statusMessage = "Mic Error: ${errorNotification.errorMsg}";
            _isListening = false;
          });
        },
      );

      setState(() {
        _speechEnabled = available;
        _statusMessage = available ? "Mic Ready" : "Google Speech Unavailable";
      });
    } catch (e) {
      setState(() {
        _speechEnabled = false;
        _statusMessage = "Init Error: $e";
      });
    }
  }

  Future<void> _listen() async {
    if (!_speechEnabled) {
      setState(() {
        _statusMessage = "Speech not available. Check Google App settings.";
      });
      await _initSpeech();
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() {
      _isListening = true;
      _userText = "Listening...";
      _statusMessage = "Listening to audio...";
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _userText = result.recognizedWords;
        });
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _sendToGemini(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      localeId: "en_US",
    );
  }

  Future<void> _sendToGemini(String prompt) async {
    setState(() {
      _jarvisResponse = "Thinking...";
      _statusMessage = "Sending request to Gemini...";
    });

    try {
      final content = [Content.text("Reply concisely as JARVIS assistant: $prompt")];
      final response = await model.generateContent(content);
      final text = response.text ?? "No response generated.";

      setState(() {
        _jarvisResponse = text;
        _statusMessage = "Answer received";
      });

      await _tts.speak(text);
    } catch (e) {
      setState(() {
        _jarvisResponse = "Error from Gemini API: $e";
        _statusMessage = "API Request Failed";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("J.A.R.V.I.S."),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.black26,
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusMessage.contains("Error") || _statusMessage.contains("Failed")
                      ? Colors.redAccent
                      : Colors.tealAccent,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "You Said:",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _userText,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const Divider(color: Colors.white24, height: 32),
                      const Text(
                        "JARVIS Response:",
                        style: TextStyle(color: Colors.tealAccent, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _jarvisResponse,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Type a prompt...",
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          setState(() => _userText = val);
                          _sendToGemini(val);
                          _textController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.tealAccent),
                    onPressed: () {
                      final val = _textController.text;
                      if (val.trim().isNotEmpty) {
                        setState(() => _userText = val);
                        _sendToGemini(val);
                        _textController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 12),
              child: FloatingActionButton.large(
                backgroundColor: _isListening ? Colors.redAccent : Colors.tealAccent,
                onPressed: _listen,
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
