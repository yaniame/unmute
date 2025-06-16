import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'task_channel',
        channelName: 'Task Notifications',
        channelDescription: 'Notifications for scheduled tasks',
        defaultColor: Colors.blue,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        playSound: true,
      )
    ],
  );
  
  // Request notification permissions
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });
  
  runApp(UnmutedApp());
}

class Task {
  String title;
  DateTime? scheduledDate;
  
  Task({required this.title, this.scheduledDate});
}

class UnmutedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unmuted',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: VoiceAssistantScreen(),
      routes: {
        '/tasks': (context) => TaskListScreen(),
      },
    );
  }
}

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  final TextEditingController _taskController = TextEditingController();
  
  late stt.SpeechToText _taskSpeech;
  bool _isListeningForTask = false;
  bool _taskSpeechEnabled = false;
  String _voiceTaskText = '';
  String _confidenceLevel = '';
  bool _speechAvailable = false;
  Timer? _autoAddTimer;
  late FlutterTts flutterTts;
  bool _isSpeaking = false;
  bool _isListeningForDateTime = false;
  String _dateTimeInput = '';

  @override
  void initState() {
    super.initState();
    _initTaskSpeech();
    _initTts();
  }

  void _initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage('en-US');
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(0.8);
    await flutterTts.setPitch(1.0);
    flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  void _speakTask(String task) async {
    if (task.trim().isNotEmpty) {
      setState(() {
        _isSpeaking = true;
      });
      
      String speechText = task;
      if (speechText.endsWith('.')) {
        speechText = speechText.substring(0, speechText.length - 1);
      }
      
      await flutterTts.speak("Task added: $speechText");
    }
  }

  void _initTaskSpeech() async {
    _taskSpeech = stt.SpeechToText();
    _speechAvailable = await _taskSpeech.initialize(
      onStatus: (val) {
        print('Speech status: $val');
        setState(() {
          if (val == 'done' || val == 'notListening') {
            _isListeningForTask = false;
            if (_voiceTaskText.isNotEmpty) {
              _processVoiceInput();
            }
          }
        });
      },
      onError: (val) {
        print('Speech error: ${val.errorMsg}');
        setState(() {
          _isListeningForTask = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice error: ${val.errorMsg}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      },
    );
    
    setState(() {
      _taskSpeechEnabled = _speechAvailable;
    });
  }

  void _startListeningForTask() async {
    if (!_taskSpeechEnabled || !_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }
    setState(() {
      _isListeningForTask = true;
      _voiceTaskText = '';
      _confidenceLevel = '';
    });
    await _taskSpeech.listen(
      onResult: (val) {
        setState(() {
          _voiceTaskText = val.recognizedWords;
          _confidenceLevel = 'Confidence: \${(val.confidence * 100).toStringAsFixed(1)}%';
        });
        if (_autoAddTimer != null) _autoAddTimer?.cancel();
        if (_voiceTaskText.isNotEmpty) {
          _autoAddTimer = Timer(Duration(seconds: 2), () {
            if (_voiceTaskText.isNotEmpty && _isListeningForTask) {
              _stopListeningForTask();
            }
          });
        }
      },
      listenFor: Duration(seconds: 15),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.confirmation,
      localeId: 'en_US',
    );
  }

  void _startListeningForDateTime() async {
    if (!_taskSpeechEnabled || !_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }
    setState(() {
      _isListeningForDateTime = true;
      _dateTimeInput = '';
    });
    await _taskSpeech.listen(
      onResult: (val) {
        setState(() {
          _dateTimeInput = val.recognizedWords;
        });
        if (_autoAddTimer != null) _autoAddTimer?.cancel();
        if (_dateTimeInput.isNotEmpty) {
          _autoAddTimer = Timer(Duration(seconds: 1), () {
            if (_dateTimeInput.isNotEmpty && _isListeningForDateTime) {
              _stopListeningForDateTime();
            }
          });
        }
      },
      listenFor: Duration(seconds: 15),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
      listenMode: stt.ListenMode.confirmation,
      localeId: 'en_US',
    );
  }

  void _stopListeningForTask() async {
    await _taskSpeech.stop();
    setState(() {
      _isListeningForTask = false;
    });
    
    if (_voiceTaskText.isNotEmpty) {
      _processVoiceInput();
    }
  }

  void _stopListeningForDateTime() async {
    await _taskSpeech.stop();
    setState(() {
      _isListeningForDateTime = false;
    });
    
    if (_dateTimeInput.isNotEmpty) {
      _processDateTimeInput();
    }
  }

  void _processVoiceInput() {
    String enhancedTask = _enhancedTaskCleaning(_voiceTaskText);
    _addTask(enhancedTask);
    setState(() {
      _voiceTaskText = '';
      _taskController.clear();
    });
  }

  void _processDateTimeInput() {
    DateTime? scheduledDateTime = _parseDateTimeFromText(_dateTimeInput);
    if (scheduledDateTime != null) {
      _scheduleNotification(_voiceTaskText, scheduledDateTime);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not understand date/time. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
    setState(() {
      _dateTimeInput = '';
    });
  }

  DateTime? _parseDateTimeFromText(String text) {
    text = text.toLowerCase();
    DateTime now = DateTime.now();
    
    // Parse relative dates
    if (text.contains('today')) {
      return now.add(Duration(minutes: 1));
    } else if (text.contains('tomorrow')) {
      return now.add(Duration(days: 1));
    } else if (text.contains('next week')) {
      return now.add(Duration(days: 7));
    } else if (text.contains('next month')) {
      return DateTime(now.year, now.month + 1, now.day);
    }
    
    // Parse specific dates
    RegExp dateRegex = RegExp(r'(\d{1,2})(?:st|nd|rd|th)? (january|february|march|april|may|june|july|august|september|october|november|december)');
    RegExp timeRegex = RegExp(r'(\d{1,2})(?::(\d{2}))?\s?(am|pm)?');
    
    Match? dateMatch = dateRegex.firstMatch(text);
    Match? timeMatch = timeRegex.firstMatch(text);
    
    int day = now.day;
    int month = now.month;
    int year = now.year;
    int hour = now.hour;
    int minute = now.minute + 1;
    
    if (dateMatch != null) {
      day = int.parse(dateMatch.group(1)!);
      String monthStr = dateMatch.group(2)!;
      month = _monthToNumber(monthStr);
      if (month < now.month) {
        year = now.year + 1;
      }
    }
    
    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!);
      if (timeMatch.group(2) != null) {
        minute = int.parse(timeMatch.group(2)!);
      }
      String? period = timeMatch.group(3);
      if (period == 'pm' && hour < 12) {
        hour += 12;
      } else if (period == 'am' && hour == 12) {
        hour = 0;
      }
    }
    
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  int _monthToNumber(String month) {
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    return months[month.toLowerCase()] ?? DateTime.now().month;
  }

  void _showDateTimePicker(String taskTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Set Reminder by Voice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Speak the date and time for your reminder'),
              SizedBox(height: 20),
              _isListeningForDateTime
                  ? Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Listening...'),
                        Text(_dateTimeInput),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: _startListeningForDateTime,
                      child: Text('Speak Date & Time'),
                    ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _scheduleNotification(String taskTitle, DateTime scheduledDate) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'task_channel',
        title: 'Task Reminder',
        body: taskTitle,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: scheduledDate.year,
        month: scheduledDate.month,
        day: scheduledDate.day,
        hour: scheduledDate.hour,
        minute: scheduledDate.minute,
        second: 0,
        millisecond: 0,
        repeats: false,
      ),
    );
    
   
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task scheduled for ${DateFormat('MMM dd, yyyy at hh:mm a').format(scheduledDate)}'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _enhancedTaskCleaning(String rawText) {
    if (rawText.isEmpty) return rawText;
    
    String cleaned = rawText.toLowerCase().trim();
    
    Map<String, String> speechCorrections = {
      'bye': 'buy',
      'by': 'buy',
      'bai': 'buy',
      'cal': 'call',
      'kall': 'call',
      'coll': 'call',
      'male': 'mail',
      'mael': 'mail',
      'send male': 'send email',
      'tak': 'take',
      'tack': 'take',
      'pic up': 'pick up',
      'pik up': 'pick up',
      'cleaner': 'clean',
      'washer': 'wash',
      'fixer': 'fix',
      'getter': 'get',
      'bringer': 'bring',
      'reminder': 'remind',
      'grocerys': 'groceries',
      'grocery': 'groceries',
      'laundri': 'laundry',
      'laundy': 'laundry',
      'dokter': 'doctor',
      'docter': 'doctor',
      'appointmet': 'appointment',
      'appointmnt': 'appointment',
      'meting': 'meeting',
      'meating': 'meeting',
      'excercise': 'exercise',
      'exersize': 'exercise',
      'medecine': 'medicine',
      'medicin': 'medicine',
    };
    
    for (String wrong in speechCorrections.keys) {
      cleaned = cleaned.replaceAll(RegExp('\\b$wrong\\b'), speechCorrections[wrong]!);
    }
    
    List<String> fillerWords = [
      'um', 'uh', 'er', 'ah', 'like', 'you know', 'well', 'so',
      'actually', 'basically', 'literally', 'kind of', 'sort of',
      'i mean', 'let me see', 'how about', 'what about', 'maybe',
      'perhaps', 'i think', 'i guess', 'probably', 'definitely'
    ];
    
    for (String filler in fillerWords) {
      cleaned = cleaned.replaceAll(RegExp('\\b$filler\\b'), '');
    }
    
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'[,]{2,}'), ',');
    cleaned = cleaned.replaceAll(RegExp(r'[.]{2,}'), '.');
    
    Map<String, String> taskPrefixes = {
      'i need to': '',
      'i have to': '',
      'i should': '',
      'i want to': '',
      'i must': '',
      'i got to': '',
      'i gotta': '',
      'remember to': '',
      'dont forget to': '',
      'don\'t forget to': '',
      'make sure to': '',
      'make sure i': '',
      'need to': '',
      'have to': '',
      'should': '',
      'gotta': '',
      'got to': '',
      'remind me to': '',
      'add task to': '',
      'add a task to': '',
      'task is to': '',
      'task is': '',
      'my task is to': '',
      'my task is': '',
    };
    
    for (String prefix in taskPrefixes.keys) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    
    Map<String, String> taskEnhancements = {
      'call the': 'Call ',
      'call my': 'Call ',
      'phone the': 'Call ',
      'phone my': 'Call ',
      'email the': 'Email ',
      'email my': 'Email ',
      'send email to': 'Email ',
      'text the': 'Text ',
      'text my': 'Text ',
      'message the': 'Text ',
      'message my': 'Text ',
      'buy some': 'Buy ',
      'purchase some': 'Buy ',
      'get some': 'Get ',
      'pick up some': 'Pick up ',
      'pick up the': 'Pick up ',
      'grab some': 'Get ',
      'grab the': 'Get ',
      'clean the': 'Clean ',
      'clean up the': 'Clean ',
      'wash the': 'Wash ',
      'fix the': 'Fix ',
      'repair the': 'Fix ',
      'schedule a': 'Schedule ',
      'book a': 'Book ',
      'make appointment with': 'Schedule appointment with ',
      'set up meeting with': 'Schedule meeting with ',
      'visit the': 'Visit ',
      'go to the': 'Go to ',
    };
    
    String originalCleaned = cleaned;
    for (String pattern in taskEnhancements.keys) {
      if (cleaned.contains(pattern)) {
        cleaned = cleaned.replaceFirst(RegExp(pattern, caseSensitive: false), taskEnhancements[pattern]!);
        break;
      }
    }
    
    cleaned = _applyContextualImprovements(cleaned);
    
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
      
      if (cleaned.length > 3 && 
          !cleaned.endsWith('.') && 
          !cleaned.endsWith('!') && 
          !cleaned.endsWith('?') &&
          !cleaned.contains('@') &&
          !cleaned.contains('http')) {
        cleaned += '.';
      }
    }
    
    if (cleaned.length < 2) {
      return originalCleaned.isNotEmpty ? originalCleaned : rawText;
    }
    
    return cleaned;
  }

  String _applyContextualImprovements(String text) {
    Map<String, String> timeContexts = {
      'tomorrow morning': 'tomorrow morning',
      'this afternoon': 'this afternoon',
      'this evening': 'this evening',
      'next week': 'next week',
      'next month': 'next month',
      'today': 'today',
      'later': 'later',
      'after work': 'after work',
      'before work': 'before work',
      'on weekend': 'on the weekend',
      'on the weekend': 'on the weekend',
    };
    
    Map<String, String> locationContexts = {
      'at the store': 'at the store',
      'at store': 'at the store',
      'at the office': 'at the office',
      'at office': 'at the office',
      'at home': 'at home',
      'at the gym': 'at the gym',
      'at gym': 'at the gym',
      'at the bank': 'at the bank',
      'at bank': 'at the bank',
    };
    
    for (String timePhrase in timeContexts.keys) {
      if (text.contains(timePhrase)) {
        text = text.replaceAll(timePhrase, timeContexts[timePhrase]!);
      }
    }
    
    for (String locationPhrase in locationContexts.keys) {
      if (text.contains(locationPhrase)) {
        text = text.replaceAll(locationPhrase, locationContexts[locationPhrase]!);
      }
    }
    
    return text;
  }

void _addTask(String task) {
  if (task.trim().isNotEmpty) {
    setState(() {
      tasks.add(Task(title: task));
      _taskController.clear();
      _voiceTaskText = '';
      _confidenceLevel = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task added successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    _speakTask(task); // Read the task out loud

    Future.delayed(Duration(seconds:3), () {
  flutterTts.speak('Enter your date please');
  // 🧠 Now listen for the date like you do for task input
    _startListeningForDateTime();
});

     // You'll implement this function below
  }
}
void _listenForDate() async {
  bool available = await _taskSpeech.initialize();

  if (available) {
    _taskSpeech.listen(
      onResult: (val) {
        if (val.finalResult) {
          String spokenDate = val.recognizedWords;
          _handleReminderDate(spokenDate);
        }
      },
    );
  }
}
void _handleReminderDate(String spokenDate) {
  // Just show it for now – you can later parse it properly into DateTime
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Reminder date set: $parseSmartDate($spokenDate)'),
      backgroundColor: Colors.blue,
      duration: Duration(seconds: 2),
    ),
  );
print(parseSmartDate(spokenDate));print("dssssssssssssssssssssssssssssssssssssss");
  flutterTts.speak('Reminder set for $spokenDate');
}
DateTime parseSmartDate(String input) {
  input = input.toLowerCase().trim();
  DateTime now = DateTime.now();

  try {
    // Try format: 2025-06-13 17:00
    DateTime parsed = DateTime.parse(input);
    if (parsed.isAfter(now)) return parsed;
  } catch (_) {}

  // Match time like '14', '14:30', '5 pm', etc.
  final timePattern = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?');
  final match = timePattern.firstMatch(input);

  if (match != null) {
    int hour = int.parse(match.group(1)!);
    int minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    String? meridiem = match.group(3);

    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;

    DateTime parsed = DateTime(now.year, now.month, now.day, hour, minute);
    if (parsed.isBefore(now)) {
      parsed = parsed.add(Duration(days: 1)); // Move to tomorrow if past
    }
    return parsed;
  }

  // Final fallback
  return now.add(Duration(minutes: 1));
}



  void _removeTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Voice Tasks'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.blue[700],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[50]!, Colors.blue[100]!],
              ),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.psychology, color: Colors.blue[700], size: 24),
                    SizedBox(width: 8),
                    Text(
                      'AI-Enhanced Voice Input',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                
                GestureDetector(
                  onTap: _taskSpeechEnabled
                      ? (_isListeningForTask ? _stopListeningForTask : _startListeningForTask)
                      : null,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    width: _isListeningForTask ? 90 : 80,
                    height: _isListeningForTask ? 90 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListeningForTask ? Colors.red[600] : Colors.blue[700],
                      boxShadow: [
                        BoxShadow(
                          color: (_isListeningForTask ? Colors.red[600] : Colors.blue[700]!)!
                              .withOpacity(0.4),
                          spreadRadius: _isListeningForTask ? 8 : 5,
                          blurRadius: _isListeningForTask ? 15 : 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListeningForTask ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: _isListeningForTask ? 40 : 35,
                    ),
                  ),
                ),
                
                SizedBox(height: 15),
                Text(
                  _isListeningForTask 
                      ? 'Listening... Tap to stop'
                      : (_taskSpeechEnabled 
                          ? 'Tap microphone and speak your task naturally'
                          : 'Voice recognition not available'),
                  style: TextStyle(
                    color: _isListeningForTask ? Colors.red[600] : Colors.grey[700],
                    fontSize: 16,
                    fontWeight: _isListeningForTask ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                if (_voiceTaskText.isNotEmpty) ...[
                  SizedBox(height: 15),
                  Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hearing, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 5),
                            Text(
                              'Voice Input:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          _voiceTaskText,
                          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                        if (_confidenceLevel.isNotEmpty) ...[
                          SizedBox(height: 5),
                          Text(
                            _confidenceLevel,
                            style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                          ),
                        ],
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.auto_fix_high, size: 16, color: Colors.blue[700]),
                            SizedBox(width: 5),
                            Text(
                              'AI Enhanced:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          _enhancedTaskCleaning(_voiceTaskText),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: 'Or type a task manually...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.edit),
                    ),
                    onSubmitted: _addTask,
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _addTask(_taskController.text),
                  child: Icon(Icons.add),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: EdgeInsets.all(15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.psychology,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 20),
                        Text(
                          'No tasks yet',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Use AI-enhanced voice input\nor type to add your first task',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              tasks[index].scheduledDate != null ? Icons.schedule : Icons.task_alt,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                          ),
                          title: Text(
                            tasks[index].title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: tasks[index].scheduledDate != null
                              ? Text(
                                  ' ${tasks[index].title}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                  ),
                                )
                              : null,
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                            onPressed: () => _removeTask(index),
                          ),
                        ),
                      );
                    },
                  )
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoAddTimer?.cancel();
    _taskSpeech.stop();
    flutterTts.stop();
    _taskController.dispose();
    super.dispose();
  }
}

class VoiceAssistantScreen extends StatefulWidget {
  @override
  _VoiceAssistantScreenState createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _lastWords = '';
  String _status = 'Tap the microphone to start listening';
  
  final String emergencyNumber = '911';
  final String momnumber = '0555555';
  final String dadnumber = '06666';
  final String doctornumber = '077777';
  
  final List<List<String>> emergencyPatterns = [
    ['call help', 'call hell', 'call held', 'call halp', 'colle help', 'col help', 'carl help', 'kall help', 'cal help'],
    ['call for help', 'call for hell', 'call for halp', 'colle for help', 'kall for help', 'cal for help', 'call for held'],
  ];
final List<List<String>> callDadPatterns = [
  ['call dad', 'col dad', 'cal dad', 'kall dad', 'call dadd', 'call dud','golden','cold father ','cold dad'],
  ['call my dad', 'call father', 'call fater', 'col my dad', 'kall father']
];
final List<List<String>> callMomPatterns = [
  ['call mom', 'col mom', 'cal mom', 'kall mom', 'call mum', 'call mam'],
  ['call my mom', 'call maam', 'col my mom', 'kall maam']
];
final List<List<String>> callDoctorPatterns = [
  ['call doctor', 'col doctor', 'cal doctor', 'kall doctor', 'call docter'],
  ['call my doctor', 'call doc', 'call dr', 'call doctar', 'call the doctor']
];


  final List<List<String>> taskPatterns = [
    ['add task', 'add ask', 'add tusk', 'ad task', 'addtasks', 'addtasks','add tosk'],
    ['create task', 'create ask', 'create tusk', 'create tasks'],
    ['new task', 'new ask', 'new tusk', 'new tasks' , 'new tosc'],
    ['open tasks', 'open task', 'show tasks', 'task list', 'tasks list'],
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _requestPermissions();
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechEnabled = await _speech.initialize(
      onStatus: (val) {
        setState(() {
          _status = 'Status: $val';
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
          }
        });
      },
      onError: (val) {
        setState(() {
          _status = 'Error: ${val.errorMsg}';
          _isListening = false;
        });
      },
    );
    
    if (_speechEnabled) {
      setState(() {
        _status = 'Ready to listen - Tap microphone';
      });
    }
  }

  void _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.phone.request();
    
    final callPermission = await Permission.phone.status;
    if (callPermission.isDenied) {
      setState(() {
        _status = 'Phone permission needed for automatic calling';
      });
    }
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    
    setState(() {
      _isListening = true;
      _status = 'Listening...';
    });
    
    await _speech.listen(
      onResult: (val) {
        setState(() {
          _lastWords = val.recognizedWords.toLowerCase();
        });
        _checkForKeywords(_lastWords);
      },
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _status = 'Stopped listening';
    });
  }

  void _checkForKeywords(String spokenText) {
    String cleanText = spokenText.toLowerCase().trim();
    
    for (List<String> patternGroup in emergencyPatterns) {
      for (String pattern in patternGroup) {
        if (cleanText.contains(pattern)) {
          _makeEmergencyCall(emergencyNumber);
          return;
        }
      }
    }
    
 for (List<String> patternGroup in callDadPatterns) {
      for (String pattern in patternGroup) {
        if (cleanText.contains(pattern)) {
          _makeEmergencyCall(dadnumber);
          return;
        }
      }
    }
 for (List<String> patternGroup in callDoctorPatterns) {
      for (String pattern in patternGroup) {
        if (cleanText.contains(pattern)) {
          _makeEmergencyCall(doctornumber);
          return;
        }
      }
    }
     for (List<String> patternGroup in callMomPatterns) {
      for (String pattern in patternGroup) {
        if (cleanText.contains(pattern)) {
          _makeEmergencyCall(momnumber);
          return;
        }
      }
    }

    for (List<String> patternGroup in taskPatterns) {
      for (String pattern in patternGroup) {
        if (cleanText.contains(pattern)) {
          _openTaskScreen();
          return;
        }
      }
    }
    
    if (_fuzzyMatchEmergencyKeywords(cleanText)) {
      _makeEmergencyCall(emergencyNumber);
      return;
    }
    
    if (_fuzzyMatchTaskKeywords(cleanText)) {
      _openTaskScreen();
    }
  }

  bool _fuzzyMatchEmergencyKeywords(String spokenText) {
    List<String> spokenWords = spokenText.split(' ');
    
    for (List<String> patternGroup in emergencyPatterns) {
      for (String pattern in patternGroup) {
        List<String> patternWords = pattern.split(' ');
        if (_isFuzzyMatch(spokenWords, patternWords)) {
          setState(() {
            _status = 'Emergency detected (fuzzy match): "$spokenText" → "$pattern"';
          });
          return true;
        }
      }
    }
    return false;
  }

  bool _fuzzyMatchTaskKeywords(String spokenText) {
    List<String> spokenWords = spokenText.split(' ');
    
    for (List<String> patternGroup in taskPatterns) {
      for (String pattern in patternGroup) {
        List<String> patternWords = pattern.split(' ');
        if (_isFuzzyMatch(spokenWords, patternWords)) {
          setState(() {
            _status = 'Task detected (fuzzy match): "$spokenText" → "$pattern"';
          });
          return true;
        }
      }
    }
    return false;
  }

  bool _isFuzzyMatch(List<String> spokenWords, List<String> patternWords) {
    if (spokenWords.isEmpty || patternWords.isEmpty) return false;
    
    if (patternWords.length == 1) {
      for (String spokenWord in spokenWords) {
        if (_calculateSimilarity(spokenWord, patternWords[0]) > 0.7) {
          return true;
        }
      }
      return false;
    }
    
    if (spokenWords.length < patternWords.length) return false;
    
    for (int i = 0; i <= spokenWords.length - patternWords.length; i++) {
      bool allMatch = true;
      for (int j = 0; j < patternWords.length; j++) {
        double similarity = _calculateSimilarity(spokenWords[i + j], patternWords[j]);
        if (similarity < 0.6) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) return true;
    }
    
    return false;
  }

  double _calculateSimilarity(String word1, String word2) {
    if (word1 == word2) return 1.0;
    if (word1.isEmpty || word2.isEmpty) return 0.0;
    
    int distance = _levenshteinDistance(word1.toLowerCase(), word2.toLowerCase());
    int maxLength = max(word1.length, word2.length);
    
    return 1.0 - (distance / maxLength);
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost
        ].reduce(min);
      }
    }

    return matrix[s1.length][s2.length];
  }

  void _makeEmergencyCall( String number) async {
    setState(() {
      _status = 'Calling emergency number...';
    });
    
    final callPermission = await Permission.phone.status;
    
    if (callPermission.isGranted) {
      final Uri directCallUri = Uri.parse('tel:$number');
      try {
        await launchUrl(
          directCallUri,
          mode: LaunchMode.externalApplication,
        );
        setState(() {
          _status = 'Emergency call initiated to $number';
        });
        return;
      } catch (e) {
        print('Direct call failed: $e');
      }
    }
    
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication,
        );
        setState(() {
          _status = 'Opening dialer for $number - Tap call button';
        });
      } else {
        setState(() {
          _status = 'Could not open phone dialer';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error making call: $e';
      });
    }
  }

  void _openTaskScreen() {
    _stopListening();
    Navigator.pushNamed(context, '/tasks');
    setState(() {
      _status = 'Opened Task Manager';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unmuted - Voice Assistant'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[50]!],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.accessibility,
                      size: 60,
                      color: Colors.blue[700],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Voice Assistant',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Say "Call Help" for emergency or "call with the name of the persson you want ex call my dad "\nSay "new Task" to manage tasks\n',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
              
              GestureDetector(
                onTap: _speechEnabled
                    ? (_isListening ? _stopListening : _startListening)
                    : null,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.red : Colors.blue[700],
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.red : Colors.blue[700]!)
                            .withOpacity(0.3),
                        spreadRadius: 10,
                        blurRadius: 20,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              
              SizedBox(height: 30),
              
              Container(
                padding: EdgeInsets.all(15),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              SizedBox(height: 20),
              
              if (_lastWords.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(15),
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'You said:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        _lastWords,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}