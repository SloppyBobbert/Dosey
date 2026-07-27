import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:flutter/material.dart';

enum CarouselHubSegment { carousel, controller }

class CarouselHubScreen extends StatefulWidget {
  const CarouselHubScreen({
    super.key,
    this.initialSegment = CarouselHubSegment.carousel,
  });

  final CarouselHubSegment initialSegment;

  @override
  State<CarouselHubScreen> createState() => _CarouselHubScreenState();
}

class _CarouselHubScreenState extends State<CarouselHubScreen> {
  late CarouselHubSegment _segment = widget.initialSegment;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<CarouselHubSegment>(
            segments: const [
              ButtonSegment(
                value: CarouselHubSegment.carousel,
                icon: Icon(Icons.view_carousel_outlined),
                label: Text('Carousel'),
              ),
              ButtonSegment(
                value: CarouselHubSegment.controller,
                icon: Icon(Icons.memory_outlined),
                label: Text('Controller'),
              ),
            ],
            selected: {_segment},
            onSelectionChanged: (selection) {
              setState(() => _segment = selection.single);
            },
          ),
        ),
        Expanded(
          child: switch (_segment) {
            CarouselHubSegment.carousel => const CarouselScreen(),
            CarouselHubSegment.controller => const ControllerScreen(),
          },
        ),
      ],
    );
  }
}
