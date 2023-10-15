import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DVB departure monitor',
      theme: ThemeData(
          useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 255, 205, 39)).copyWith(background: Colors.black)
      ),
      home: const MyHomePage(title: 'DVB departure monitor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Timer? timer;
  final DateFormat dateTimeFormat = DateFormat("dd.MM.yyyy HH:mm:ss");
  final Map<String, String> states = {
    "Delayed" : "verspätet",
    "InTime"  : "pünktlich",
    "Canceled": "Zug fällt aus!",
    "undefined" : "unbekannt"
  };
  late String time;
  var listEntries = <Widget>[];
  late String _title = "";

  void _postRequest () async {
    String stopId = "33000131";
    Map data = {
      'apikey': '12345678901234567890',
      "stopid": stopId,
      "isarrival": false,
      "shorttermchanges": true,
      "mentzonly": false
    };
    var body = json.encode(data);
    var response = await http.post(Uri.https("webapi.vvo-online.de", "dm"),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: body
    );
    var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
    setState(() {
      _title = decodedResponse["Place"] + " " + decodedResponse["Name"];
      listEntries.clear();
      var departures = decodedResponse["Departures"] as List;
      for (var i = 0; i < departures.length; i++) {
        var data = departures[i] as Map;
        var time = DateTime.fromMillisecondsSinceEpoch(int.parse(data["ScheduledTime"].substring(6, 19)));
        var departureTime = DateFormat("HH:mm").format(time);//.substring(0, 5);
        String state = states[(data["State"] ?? "InTime")] ?? "unbekannt";
        String lineDirection = data["LineName"] + " " + data["Direction"];
        late String delay;
        late Color color;
        if (state == "unbekannt") {
          delay = "";
          state = " keine Echtzeitdaten verfügbar.";
          color = Colors.grey;
        } else {
          var delayCalc = ((int.parse(data["RealTime"].substring(6, 19)) - int.parse(data["ScheduledTime"].substring(6, 19)))/60000).floor();
          String direction = data["Direction"];
          if (delayCalc > 0) {
            delay = " +$delayCalc";
            color = Colors.red;
          } else if (direction.contains(" fällt aus")) {
            delay = "";
            state = " Zug fällt aus !";
            color = Colors.red;
          } else {
            delay = "";
            color = Colors.green;
          }
        }
        int minutes = ((time.compareTo(DateTime.now()))/60000).floor();
        String minutesText = " in {$minutes} ";
        if (minutes < 1) {
          minutesText = "jetzt";
        } else if (minutes == 1) {
          minutesText += "Minute";
        } else {
          minutesText += "Minuten";
        }
        listEntries.add(Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    lineDirection, style: const TextStyle(color: Color.fromARGB(255, 255, 205, 39), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    data["Mot"], style: const TextStyle(color: Color.fromARGB(255, 255, 205, 39), fontSize: 18),
                  ),
                ),
                Align(
                    alignment: Alignment.topRight,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          departureTime, style: const TextStyle(color: Color.fromARGB(255, 255, 205, 39), fontSize: 18),
                        ),
                        Text(
                          delay, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    )
                ),
              ],
            ),
            Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    state, style: TextStyle(color: color, fontSize: 18),
                  ),
                ),
                Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      minutesText, style: const TextStyle(color: Color.fromARGB(255, 255, 205, 39), fontSize: 18),
                    ),
                ),
              ],
            ),
            const Divider(
              color: Colors.white,
            ),
            const SizedBox(height: 10,)
          ],
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _postRequest();
    time = dateTimeFormat.format(DateTime.now());
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final DateTime dateTime = DateTime.now();
      final String printable = dateTimeFormat.format(dateTime);
      final oldParts = time.split(":");
      final parts = printable.split(":");
      final oldSeconds = oldParts[2];
      final seconds = parts[2];
      if (oldSeconds != seconds) {
        setState(() {
          time = printable;
          if (seconds == "00") {
            _postRequest();
          }
        });
      }
    });
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 20,
          children: [
            Stack(
              children: [
                Container(
                  margin: EdgeInsets.fromLTRB(0, height * 0.02, width * 0.02, 0),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      time,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.fromLTRB(width * 0.02, height * 0.02, 0, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      _title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color.fromARGB(255, 255, 205, 39)),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              margin: EdgeInsets.fromLTRB(width * 0.02, height * 0.02, width * 0.02, height * 0.02),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: listEntries,
              ),
            ),
          ],
        ),
      ),
    );
  }
}