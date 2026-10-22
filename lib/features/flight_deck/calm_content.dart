// lib/features/flight_deck/calm_content.dart
/// Bundled, offline calm-kit content for the Flight Deck. ids are stable
/// slugs: favorites persist them, so never rename an id.
enum CalmKind { fact, tip }

class CalmCard {
  const CalmCard({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
  });

  final String id;
  final CalmKind kind;
  final String title;
  final String body;
}

const List<CalmCard> calmCards = [
  // Facts (10).
  CalmCard(id: 'fact-odds', kind: CalmKind.fact, title: 'Flying is the safest way to travel', body: 'About 1 in 11 million flights has a fatal accident — you are safer in the air than on the drive to the airport.'),
  CalmCard(id: 'fact-turbulence', kind: CalmKind.fact, title: 'Turbulence is uncomfortable, not dangerous', body: 'Planes are built to handle forces far beyond any turbulence, and it has never brought down a modern airliner. Think of it as bumps on a road.'),
  CalmCard(id: 'fact-sounds', kind: CalmKind.fact, title: 'Those sounds are normal', body: 'Clunks after takeoff are the landing gear retracting; dings are crew signals; engine pitch changes are routine power adjustments.'),
  CalmCard(id: 'fact-wings', kind: CalmKind.fact, title: 'Wings flex by design', body: 'A wing tip can bend several metres in testing without damage. Flexing you see from the window is the wing doing its job.'),
  CalmCard(id: 'fact-pilots', kind: CalmKind.fact, title: 'Two trained pilots, always', body: 'Every airliner flies with two fully qualified pilots who rehearse emergencies in simulators every six months.'),
  CalmCard(id: 'fact-backups', kind: CalmKind.fact, title: 'Everything important has a backup', body: 'Engines, hydraulics, electrics and instruments are all redundant — a plane lands safely even after several failures.'),
  CalmCard(id: 'fact-one-engine', kind: CalmKind.fact, title: 'One engine is enough', body: 'Twin-engine airliners climb and land on a single engine, and pilots practise exactly that in the simulator.'),
  CalmCard(id: 'fact-weather', kind: CalmKind.fact, title: 'Storms are flown around, not through', body: 'Dispatchers and radar keep flights clear of severe weather; a bumpy detour means the crew chose the safer path.'),
  CalmCard(id: 'fact-crew-calm', kind: CalmKind.fact, title: 'Watch the crew, not the window', body: 'If the cabin crew are calmly serving drinks, nothing is wrong — they feel the same bumps and know they are routine.'),
  CalmCard(id: 'fact-landing', kind: CalmKind.fact, title: 'Landings are firm on purpose', body: 'A positive touchdown keeps the wheels gripping the runway, especially when it is wet. A firm landing is a good landing.'),
  // Tips (8).
  CalmCard(id: 'tip-breathing', kind: CalmKind.tip, title: 'Slow your exhale', body: 'Breathe in 4 seconds, hold 4, out 6. Long exhales tell your nervous system the danger has passed. Try it in the timer below.'),
  CalmCard(id: 'tip-seat', kind: CalmKind.tip, title: 'Sit over the wing', body: 'Seats over the wing feel the least motion. A window seat also gives you a stable horizon to look at.'),
  CalmCard(id: 'tip-crew', kind: CalmKind.tip, title: 'Tell the crew you are nervous', body: 'Flight attendants help nervous flyers every day. Saying so out loud often halves the anxiety on its own.'),
  CalmCard(id: 'tip-caffeine', kind: CalmKind.tip, title: 'Skip the extra coffee', body: 'Caffeine mimics anxiety: racing heart, jitters, alertness. Water and a light meal keep your body calmer.'),
  CalmCard(id: 'tip-arrive', kind: CalmKind.tip, title: 'Arrive early, rush less', body: 'Most panic starts with running late. Being at the gate with time to spare removes the biggest controllable stressor.'),
  CalmCard(id: 'tip-distraction', kind: CalmKind.tip, title: 'Plan your distraction', body: 'Download a film, an album and a puzzle before boarding. Giving your brain a job leaves less room for worry.'),
  CalmCard(id: 'tip-feet', kind: CalmKind.tip, title: 'Plant your feet', body: 'Press both feet flat into the floor and notice the pressure. Grounding through your body interrupts spiralling thoughts.'),
  CalmCard(id: 'tip-turbulence-plan', kind: CalmKind.tip, title: 'Have a turbulence plan', body: 'Decide now: seatbelt on, sip water, run the breathing timer. A rehearsed plan turns bumps into routine.'),
];
