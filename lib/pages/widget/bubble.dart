import 'package:audioplayers/audioplayers.dart';
import 'package:bubble_grow/model/models.dart';
import 'package:bubble_grow/utils/constant.dart';
import 'package:flutter/material.dart';

class Bubble extends StatefulWidget {
  final String rule;

  final Color ruleColour;
  final Color colour;
  final int? ruleNumber;
  final int? number;

  final ValueChanged<Move> parentAction;
  final String colorName;
  final int index;

  const Bubble({
    super.key,
    required this.rule,
    required this.parentAction,
    required this.index,
    required this.ruleColour,
    required this.colour,
    required this.colorName,
    this.ruleNumber,
    this.number,
  });

  @override
  BubbleState createState() => BubbleState();
}

class BubbleState extends State<Bubble> {
  double width = 80;
  Color? color;

  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    color = widget.colour;
  }

  @override
  void dispose() {
    color = null;
    super.dispose();
  }

  void _playSound() {
    player.play(AssetSource('pop.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _playSound();
        late Move move;
        switch (widget.rule) {
          case 'C':
            move = Move(widget.colorName, widget.index,
                widget.colour == widget.ruleColour);
            break;
          case 'N':
            move = Move(widget.colorName, widget.index,
                ((widget.number ?? 0) % (widget.ruleNumber ?? 0) == 0));
            break;
          case 'NC':
            move = Move(
                widget.colorName,
                widget.index,
                widget.colour == widget.ruleColour &&
                    ((widget.number ?? 0) % (widget.ruleNumber ?? 0) == 0));
            break;
        }

        setState(() {
          width = 0;
          color = Colors.white.withOpacity(0.5);
        });

        WidgetsBinding.instance
            .addPostFrameCallback((_) => widget.parentAction(move));
      },
      child: AnimatedContainer(
        height: width,
        width: width,
        duration: const Duration(seconds: 1),
        curve: Curves.fastOutSlowIn,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(pathImage(widget.colorName)),
            fit: BoxFit.cover,
          ),
        ),
        margin: const EdgeInsets.all(5),
        child: widget.number != null
            ? Center(
                child: Text(
                  widget.number.toString(),
                  style: const TextStyle(fontSize: 20),
                ),
              )
            : const SizedBox(),
      ),
    );
  }
}
