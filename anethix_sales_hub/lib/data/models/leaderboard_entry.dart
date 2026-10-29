class LeaderboardEntry {
  const LeaderboardEntry({
    required this.employeeId,
    required this.employeeName,
    required this.leadsTaken,
    required this.callsMade,
    required this.followUpsCompleted,
    required this.meetings,
    required this.won,
    required this.score,
    this.rank = 0,
  });

  final String employeeId;
  final String employeeName;
  final int leadsTaken;
  final int callsMade;
  final int followUpsCompleted;
  final int meetings;
  final int won;
  final int score;
  final int rank;

  LeaderboardEntry copyWith({
    String? employeeId,
    String? employeeName,
    int? leadsTaken,
    int? callsMade,
    int? followUpsCompleted,
    int? meetings,
    int? won,
    int? score,
    int? rank,
  }) {
    return LeaderboardEntry(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      leadsTaken: leadsTaken ?? this.leadsTaken,
      callsMade: callsMade ?? this.callsMade,
      followUpsCompleted: followUpsCompleted ?? this.followUpsCompleted,
      meetings: meetings ?? this.meetings,
      won: won ?? this.won,
      score: score ?? this.score,
      rank: rank ?? this.rank,
    );
  }
}
