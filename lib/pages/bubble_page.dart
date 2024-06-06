import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:bubble_grow/model/models.dart';
import 'package:bubble_grow/pages/widget/bubble.dart';
import 'package:bubble_grow/utils/constant.dart';
import 'package:bubble_grow/utils/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';

final backgroundMusic = signal(true);

class BubblePage extends StatefulWidget {
  static String id = 'game_screen';

  const BubblePage({super.key});

  @override
  BubblePageState createState() => BubblePageState();
}

class BubblePageState extends State<BubblePage> {
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  final playerBackground = AudioPlayer();
  final random = Random();
  final Map<String, ColorState> colours = {
    'Reds': ColorState(Colors.red), // 336
    'Purples': ColorState(Colors.purple), // 27b0
    'Yellows': ColorState(Colors.yellow), // eb3b
    'Blues': ColorState(Colors.cyan), // bcd4
    'Greens': ColorState(Colors.lightGreenAccent), // ff59
  };

  var bubbles = <BubbleModel>[];
  int level = 0;

  late String rule;
  late String ruleColorName;
  late int ruleNumber;
  late int ruleCount;

  Timer? _timer;
  int _start = 10;

  bool correctMove = true, showOverlay = false, gameOver = false;

  int popped = 0;

  late Future<void> loadLevelFuture;
  bool isPlaying = true;

  @override
  void initState() {
    super.initState();
    _loadAd();
    _loadInterstitialAd();
    loadLevelFuture = _loadLevel();
    _loadGame();
  }

  void playBackgroundMusic() async {
    await playerBackground.play(AssetSource('Mr_Smith-Sonorus.mp3'));
    await playerBackground.setReleaseMode(ReleaseMode.loop);
  }

  void stopBackgroundMusic() async {
    await playerBackground.stop();
  }

  Future<void> _loadLevel() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    level = prefs.getInt('level') ?? 0;
  }

  void _loadGame() {
    if (backgroundMusic.value) {
      playBackgroundMusic();
    }
    rule = kRules.keys.elementAt(random.nextInt(3));
    ruleColorName = colours.keys.elementAt(random.nextInt(colours.length));
    ruleNumber = 1 + random.nextInt(6 - 1); // to ensure non-zero number always

    bubbles.clear();
    bubbles = List.generate(
      // at least 18 bubbles, at most 30 bubbles
      (6 * 3) + random.nextInt((6 * 4) - 11),
      (index) => BubbleModel(
        colorIndex: random.nextInt(colours.length),
        number: rule.contains('N') ? index + 1 : null,
      ),
    );

    for (var element in colours.values) {
      element.resetCount();
    }

    for (var item in bubbles) {
      colours.values.elementAt(item.colorIndex).incrementCount();
    }

    switch (rule) {
      case 'C':
        ruleCount = colours[ruleColorName]?.count ?? 0;
        break;

      case 'N':
        ruleCount = (bubbles.length / ruleNumber).floor();
        break;

      case 'NC':
        ruleCount = bubbles
            .where((element) =>
                element.colorIndex ==
                    colours.keys.toList().indexOf(ruleColorName) &&
                (element.number ?? 0) % ruleNumber == 0)
            .length;
        break;
    }

    if (gameOver && showOverlay) {
      setState(() {
        gameOver = false;
        showOverlay = false;
        popped = 0;
        correctMove = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final music = backgroundMusic.watch(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/bg.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {
                        backgroundMusic.value = !music;
                        if (backgroundMusic.watch(context)) {
                          playBackgroundMusic();
                        } else {
                          stopBackgroundMusic();
                        }
                        final snackBar = SnackBar(
                          content: Text('Music ${!music ? 'ON' : 'OFF'}'),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      },
                      icon: Icon(
                        music
                            ? Icons.music_note_sharp
                            : Icons.music_off_outlined,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  FutureBuilder<void>(
                      future: loadLevelFuture,
                      builder: (context, snapshot) {
                        return Text(
                          'Level $level',
                          style: const TextStyle(fontSize: 22),
                        );
                      }),
                  Text(
                    'Pop the ${_getRule(rule, ruleColorName, ruleNumber)}',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const Spacer(),
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: bubbles.length,
                    padding:
                        const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
                    itemBuilder: (context, index) {
                      Color randColor = colours.values
                          .elementAt(bubbles[index].colorIndex)
                          .color;
                      String colorName =
                          colours.keys.elementAt(bubbles[index].colorIndex);
                      return bubbles[index].isActive
                          ? Bubble(
                              rule: rule,
                              ruleColour: colours[ruleColorName]!.color,
                              colour: randColor,
                              // colorName used as key from colours map to manipulate colour count after a move
                              colorName: colorName,
                              ruleNumber:
                                  rule.contains('N') ? ruleNumber : null,
                              number: rule.contains('N') ? index + 1 : null,
                              parentAction: _updateMove,
                              index: index,
                            )
                          : const SizedBox();
                    },
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                  onPressed: () {
                    if (ruleCount == 0 && popped == 0) {
                      _gameWon();
                    } else {
                      _gameOver();
                    }
                  },
                  child: const Text(
                    'Don\'t Fool Me!',
                    style: TextStyle(fontSize: 18, color: Colors.black),
                  ),
                ),
              ),
              Visibility(
                visible: showOverlay,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200.withOpacity(0.5)),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Visibility(
                  visible: showOverlay,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        gameOver ? 'GAME OVER' : 'LEVEL UP!',
                        style: const TextStyle(fontSize: 40),
                      ),
                      ElevatedButton(
                        child: Text(gameOver ? 'Play Again' : 'Next Level'),
                        onPressed: () {
                          _interstitialAd?.show();
                          if (kDebugMode) {
                            print('rebuilding..');
                          }
                          Navigator.pushReplacementNamed(
                              context, BubblePage.id);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: SizedBox(
                    width: AdSize.banner.width.toDouble(),
                    height: AdSize.banner.height.toDouble(),
                    child: _bannerAd == null
                        // Nothing to render yet.
                        ? const SizedBox()
                        // The actual ad.
                        : AdWidget(ad: _bannerAd!),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadAd() {
    final bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: Environment.unitBanner,
      request: const AdRequest(),
      listener: BannerAdListener(
        // Called when an ad is successfully received.
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        // Called when an ad request failed.
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );

    // Start loading.
    bannerAd.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
        adUnitId: Environment.unitInterstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          // Called when an ad is successfully received.
          onAdLoaded: (ad) {
            debugPrint('$ad loaded.');
            // Keep a reference to the ad so you can show it later.
            _interstitialAd = ad;
          },
          // Called when an ad request failed.
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('InterstitialAd failed to load: $error');
          },
        ));
  }

  /// returns rule String to be displayed at the top
  String _getRule(String rule, String colorName, int number) {
    switch (rule) {
      case 'C':
        return colorName;
      case 'N':
        return 'Multiples of $number';
      case 'NC':
        return '$colorName that are Multiples of $number';
      default:
        return colorName;
    }
  }

  /// takes a Move object for the latest Move made, determines whether the correct move was made,
  /// manipulates colour count and removes that bubble from the Grid,
  /// and renders overlay in case of wrong move or
  /// level up (if no. of popped bubbles is equal to the original rule count,
  /// i.e. no. of bubbles satisfying the rule)
  void _updateMove(Move currentMove) {
    setState(() {
      correctMove = currentMove.isCorrectMove;
      popped++;
      bubbles[currentMove.index].isActive = false;
      colours[currentMove.colorName]?.decrementCount();
    });

    if (!correctMove) {
      _gameOver();
    } else if (correctMove && popped == ruleCount) {
      _gameWon();
    }
  }

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) => setState(
        () {
          if (_start < 1) {
            timer.cancel();
          } else {
            _start = _start - 1;
          }
        },
      ),
    );
  }

  void _gameOver() {
    if (kDebugMode) {
      print('Game Over!');
    }
    setState(() {
      gameOver = true;
      showOverlay = true;
    });
  }

  Future<void> _gameWon() async {
    if (kDebugMode) {
      print('Woohoo, you won!!');
    }
    // update level in SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('level', level + 1);
    setState(() {
      showOverlay = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    colours.clear();
    bubbles.clear();
    _bannerAd?.dispose();
    playerBackground.dispose();
    playerBackground.stop();
    super.dispose();
  }
}
