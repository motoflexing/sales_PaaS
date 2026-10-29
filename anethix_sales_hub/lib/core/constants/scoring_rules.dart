/// Point values awarded per action. Hardcoded for V1; moves to remote config
/// once the backend lands.
const Map<String, int> scoringRules = {
  'leadTaken': 1,
  'connectedCall': 2,
  'completedFollowUp': 3,
  'meeting': 5,
  'wonLead': 10,
};

class ScoringRules {
  const ScoringRules._();

  static int get leadTaken => scoringRules['leadTaken']!;
  static int get connectedCall => scoringRules['connectedCall']!;
  static int get completedFollowUp => scoringRules['completedFollowUp']!;
  static int get meeting => scoringRules['meeting']!;
  static int get wonLead => scoringRules['wonLead']!;

  static int total({
    required int leadsTaken,
    required int connectedCalls,
    required int completedFollowUps,
    required int meetings,
    required int won,
  }) =>
      leadsTaken * leadTaken +
      connectedCalls * connectedCall +
      completedFollowUps * completedFollowUp +
      meetings * meeting +
      won * wonLead;
}
