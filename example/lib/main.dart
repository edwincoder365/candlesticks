import 'dart:convert';
import 'package:candlesticks_plus/candlesticks_plus.dart';
import 'package:example/generated/l10n.dart';
import 'package:example/repo.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
/*   @override
  void initState() {
    fetchCandles().then((value) {
      setState(() {
        candles = value;
      });
    });
    super.initState();
  } */

  /* Future<List<Candle>> fetchCandles({String interval = '1h'}) async {
    final uri = Uri.parse(
        "https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=$interval");
    final res = await http.get(uri);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => Candle.fromJson(e))
        .toList()
        .reversed
        .toList();
  } */

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        AppLocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizationDelegate().supportedLocales,
      home: Home(),
    );
  }
}

class CandleTickerModel {
  final int eventTime;
  final String symbol;
  final Candle candle;

  const CandleTickerModel(
      {required this.eventTime, required this.symbol, required this.candle});

  factory CandleTickerModel.fromJson(Map<String, dynamic> json) {
    return CandleTickerModel(
        eventTime: json['E'] as int,
        symbol: json['s'] as String,
        candle: Candle(
            date: DateTime.fromMillisecondsSinceEpoch(json["k"]["t"]),
            high: double.parse(json["k"]["h"]),
            low: double.parse(json["k"]["l"]),
            open: double.parse(json["k"]["o"]),
            close: double.parse(json["k"]["c"]),
            volume: double.parse(json["k"]["v"])));
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Candle> candles = [];
  bool themeIsDark = false;
  WebSocketChannel? _channel;
  BinanceRepository repository = BinanceRepository();
  String currentInterval = "1m";
  List<String> symbols = [];
  String currentSymbol = "";
  final intervals = [
    '1h',
    '2h',
    '4h',
    '1d',
    '1w',
    '1M',
  ];

  @override
  void dispose() {
    if (_channel != null) _channel!.sink.close();
    super.dispose();
  }

  Future<void> fetchCandles(String symbol, String interval) async {
    // close current channel if exists
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    // clear last candle list
    setState(() {
      candles = [];
      currentInterval = interval;
    });

    try {
      // load candles info
      final data =
          await repository.fetchCandles(symbol: symbol, interval: interval);
      // connect to binance stream
      _channel =
          repository.establishConnection(symbol.toLowerCase(), currentInterval);
      // update candles
      setState(() {
        print(data);
        candles = data;
        currentInterval = interval;
        currentSymbol = symbol;
      });
    } catch (e) {
      // handle error
      return;
    }
  }

  Future<List<String>> fetchSymbols() async {
    try {
      // load candles info
      final data = await repository.fetchSymbols();
      return data;
    } catch (e) {
      // handle error
      return [];
    }
  }

  @override
  void initState() {
    fetchSymbols().then((value) {
      symbols = value;
      if (symbols.isNotEmpty) fetchCandles(symbols[0], currentInterval);
    });
    super.initState();
  }

  Future<void> loadMoreCandles() async {
    try {
      // load candles info
      final data = await repository.fetchCandles(
          symbol: currentSymbol,
          interval: currentInterval,
          endTime: candles.last.date.millisecondsSinceEpoch);
      candles.removeLast();
      setState(() {
        candles.addAll(data);
      });
    } catch (e) {
      // handle error
      return;
    }
  }

  void updateCandlesFromSnapshot(AsyncSnapshot<Object?> snapshot) {
    if (candles.isEmpty) return;
    if (snapshot.data != null) {
      final map = jsonDecode(snapshot.data as String) as Map<String, dynamic>;
      if (map.containsKey("k") == true) {
        final candleTicker = CandleTickerModel.fromJson(map);

        // cehck if incoming candle is an update on current last candle, or a new one
        if (candles[0].date == candleTicker.candle.date &&
            candles[0].open == candleTicker.candle.open) {
          // update last candle
          candles[0] = candleTicker.candle;
        }
        // check if incoming new candle is next candle so the difrence
        // between times must be the same as last existing 2 candles
        else if (candleTicker.candle.date.difference(candles[0].date) ==
            candles[0].date.difference(candles[1].date)) {
          // add new candle to list
          candles.insert(0, candleTicker.candle);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$currentSymbol $currentInterval Chart"),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                themeIsDark = !themeIsDark;
              });
            },
            icon: Icon(
              themeIsDark
                  ? Icons.wb_sunny_sharp
                  : Icons.nightlight_round_outlined,
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return Center(
                    child: Container(
                      width: 200,
                      color: Theme.of(context).backgroundColor,
                      child: Wrap(
                        children: intervals
                            .map((e) => Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: 50,
                                    height: 30,
                                    child: RawMaterialButton(
                                      elevation: 0,
                                      fillColor: const Color(0xFF494537),
                                      onPressed: () {
                                        fetchCandles(currentSymbol, e);
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        e,
                                        style: const TextStyle(
                                          color: Color(0xFFF0B90A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  );
                },
              );
            },
            icon: Icon(Icons.more_horiz_outlined),
          )
        ],
      ),
      body: Center(
        child: StreamBuilder(
          stream: _channel == null ? null : _channel!.stream,
          builder: (context, snapshot) {
            updateCandlesFromSnapshot(snapshot);
            return Column(
              children: [
                Container(
                  color: themeIsDark ? const Color(0xFF191B20) : Colors.white,
                  height: 80,
                  width: double.maxFinite,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: ListView(
                      //mainAxisAlignment: MainAxisAlignment.start,
                      //crossAxisAlignment: CrossAxisAlignment.center,
                      //mainAxisSize: MainAxisSize.min,
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (!snapshot.hasData)
                          const Text(
                            'Loading... ',
                            style: TextStyle(color: Colors.grey),
                          ),
                        if (snapshot.hasData)
                          InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                backgroundColor: Colors.transparent,
                                context: context,
                                builder: (context) {
                                  return SymbolsSearchModal(
                                    onSelect: (symbol) {
                                      setState(() {
                                        currentSymbol = symbol;
                                        fetchCandles(symbol, currentInterval);
                                      });
                                    },
                                    symbols: symbols,
                                  );
                                },
                              );
                            },
                            child: Text(
                              currentSymbol,
                              style: const TextStyle(
                                fontSize: 20,
                              ),
                            ),
                          ),
                        const SizedBox(width: 20),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              candles.isNotEmpty
                                  ? candles.last.close.toStringAsFixed(2)
                                  : "0.00",
                              style: TextStyle(
                                fontSize: 15,
                                color: candles.isNotEmpty
                                    ? candles.last.close >
                                            candles[candles.length - 2].close
                                        ? Colors.green
                                        : Colors.red
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "\$${candles.isNotEmpty ? candles.last.close.toStringAsFixed(2) : ""}",
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Open',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(candles.isNotEmpty
                                ? candles.last.open.toStringAsFixed(2)
                                : "0.00"),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Close',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(candles.isNotEmpty
                                ? candles.last.close.toStringAsFixed(2)
                                : "0.00"),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'High',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(candles.isNotEmpty
                                ? candles.last.high.toStringAsFixed(2)
                                : "0.00"),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Low',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(candles.isNotEmpty
                                ? candles.last.low.toStringAsFixed(2)
                                : "0.00"),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(candles.isNotEmpty
                                ? (candles.last.close - candles.last.open)
                                    .toStringAsFixed(2)
                                : "0.00"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Show Streaming data in json form
                // Text(snapshot.hasData ? '${snapshot.data}' : ''),
                const Divider(
                  height: 1,
                  color: Colors.grey,
                ),
                Expanded(
                  child: Candlesticks(
                    key: Key(currentSymbol + currentInterval),
                    //indicators: indicators,
                    candles: candles,
                    onLoadMoreCandles: loadMoreCandles,
                    /* onRemoveIndicator: (String indicator) {
                        setState(() {
                          indicators = [...indicators];
                          indicators.removeWhere(
                              (element) => element.name == indicator);
                        });
                      }, */
                    actions: [
                      ToolBarAction(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Center(
                                child: Container(
                                  width: 200,
                                  color: Theme.of(context).backgroundColor,
                                  child: Wrap(
                                    children: intervals
                                        .map((e) => Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: SizedBox(
                                                width: 50,
                                                height: 30,
                                                child: RawMaterialButton(
                                                  elevation: 0,
                                                  fillColor:
                                                      const Color(0xFF494537),
                                                  onPressed: () {
                                                    fetchCandles(
                                                        currentSymbol, e);
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text(
                                                    e,
                                                    style: const TextStyle(
                                                      color: Color(0xFFF0B90A),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Text(
                          currentInterval,
                        ),
                      ),
                      /* ToolBarAction(
                          width: 100,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return SymbolsSearchModal(
                                  symbols: symbols,
                                  onSelect: (value) {
                                    fetchCandles(value, currentInterval);
                                  },
                                );
                              },
                            );
                          },
                          child: Text(
                            currentSymbol,
                          ),
                        ) */
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SymbolsSearchModal extends StatefulWidget {
  final Function(String symbol) onSelect;

  final List<String> symbols;
  const SymbolsSearchModal({
    Key? key,
    required this.onSelect,
    required this.symbols,
  }) : super(key: key);

  @override
  State<SymbolsSearchModal> createState() => _SymbolSearchModalState();
}

class _SymbolSearchModalState extends State<SymbolsSearchModal> {
  String symbolSearch = "";
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          height: MediaQuery.of(context).size.height * 0.75,
          color: Theme.of(context).backgroundColor.withOpacity(0.5),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      symbolSearch = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  children: widget.symbols
                      .where((element) => element
                          .toLowerCase()
                          .contains(symbolSearch.toLowerCase()))
                      .map((e) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 50,
                              height: 30,
                              child: RawMaterialButton(
                                elevation: 0,
                                fillColor: const Color(0xFF494537),
                                onPressed: () {
                                  widget.onSelect(e);
                                  Navigator.of(context).pop();
                                },
                                child: Text(
                                  e,
                                  style: const TextStyle(
                                    color: Color(0xFFF0B90A),
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
