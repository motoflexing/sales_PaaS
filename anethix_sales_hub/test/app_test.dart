import 'package:anethix_sales_hub/core/constants/lead_status.dart';
import 'package:anethix_sales_hub/core/constants/scoring_rules.dart';
import 'package:anethix_sales_hub/core/utils/validators.dart';
import 'package:anethix_sales_hub/shared/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lead status machine', () {
    test('a claimed lead can only move forward, or to lost', () {
      final next = allowedNextStatuses(LeadStatus.claimed);

      expect(next, contains(LeadStatus.contacted));
      expect(next, contains(LeadStatus.won));
      expect(next, contains(LeadStatus.lost));
      expect(next, isNot(contains(LeadStatus.claimed)));
      expect(next, isNot(contains(LeadStatus.draft)));
      expect(next, isNot(contains(LeadStatus.live)));
    });

    test('a lead never moves backwards', () {
      final next = allowedNextStatuses(LeadStatus.meeting);

      expect(next, isNot(contains(LeadStatus.contacted)));
      expect(next, isNot(contains(LeadStatus.interested)));
      expect(next, containsAll([LeadStatus.proposal, LeadStatus.won]));
    });

    test('won and lost are terminal', () {
      expect(allowedNextStatuses(LeadStatus.won), isEmpty);
      expect(allowedNextStatuses(LeadStatus.lost), isEmpty);
      expect(isTerminal(LeadStatus.won), isTrue);
      expect(isTerminal(LeadStatus.contacted), isFalse);
    });
  });

  group('scoring', () {
    test('totals each action at its configured point value', () {
      final score = ScoringRules.total(
        leadsTaken: 3,
        connectedCalls: 4,
        completedFollowUps: 2,
        meetings: 1,
        won: 1,
      );

      // 3*1 + 4*2 + 2*3 + 1*5 + 1*10
      expect(score, 32);
    });

    test('an untouched employee scores zero', () {
      expect(
        ScoringRules.total(
          leadsTaken: 0,
          connectedCalls: 0,
          completedFollowUps: 0,
          meetings: 0,
          won: 0,
        ),
        0,
      );
    });
  });

  group('validators', () {
    test('accepts a 10-digit Indian mobile number', () {
      expect(Validators.phone('9876543210'), isNull);
      expect(Validators.phone('6123456789'), isNull);
    });

    test('rejects malformed phone numbers', () {
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone('5876543210'), isNotNull);
      expect(Validators.phone('98765432101'), isNotNull);
      expect(Validators.phone(''), isNotNull);
    });

    test('optional phone tolerates an empty value', () {
      expect(Validators.phone('', isRequired: false), isNull);
    });

    test('validates email format', () {
      expect(Validators.email('rahul@anethix.com'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('', isRequired: false), isNull);
    });
  });

  // The claim-transaction and import tests that used to live here drove the
  // in-memory mock database directly. Both paths are now Firestore writes — a
  // `runTransaction` for the claim, a batched write for the import — and need a
  // Firestore fake or the emulator to exercise, rather than a repository
  // constructed against an in-memory list. See firestore.rules for the
  // server-side half of the same guarantees.
}
