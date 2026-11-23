import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'project_repository.dart';
import '../../project/data/mock_repository_support.dart';
import '../../project/domain/data_failure.dart';
import '../../project/domain/disbursement.dart';

/// Data source contract for fund disbursements (P04 Penyaluran Dana).
///
/// UI code depends on this interface only, so the mock implementation can be
/// replaced by an API client later without rewriting pages. All methods are
/// asynchronous and location ids match the P04 project ids.
abstract interface class DisbursementRepository {
  /// Disbursements for one location, newest first.
  ///
  /// Returns an empty list when the location has no disbursements. Throws
  /// [LocationNotFoundException] when [locationId] is unknown.
  ///
  /// ```dart
  /// final entries = await repository.getDisbursementsByLocation('p01');
  /// ```
  Future<List<Disbursement>> getDisbursementsByLocation(
    String locationId, {
    DisbursementStatus? status,
  });

  /// One disbursement by its unique [id].
  ///
  /// Throws [DisbursementNotFoundException] when no disbursement has that id.
  ///
  /// ```dart
  /// final entry = await repository.getDisbursementById('dis001');
  /// ```
  Future<Disbursement> getDisbursementById(String id);

  /// Aggregate money movement totals for one location.
  ///
  /// [collected] is the funds raised for the location, [disbursed] the funds
  /// that reached the field and [pending] the funds raised but not disbursed
  /// yet. Totals never exceed the collected amount.
  ///
  /// Throws [LocationNotFoundException] when [locationId] is unknown.
  ///
  /// ```dart
  /// final summary = await repository.getDisbursementSummary('p01');
  /// ```
  Future<DisbursementSummary> getDisbursementSummary(String locationId);
}

/// Mock implementation reading `assets/mock/disbursements.json` and
/// `assets/mock/projects.json`.
class MockDisbursementRepository implements DisbursementRepository {
  MockDisbursementRepository({this.latency, this.forceError = false});

  static const _disbursementsAsset = 'assets/mock/disbursements.json';

  /// Simulated call delay; null means a random 300–800 ms delay.
  final Duration? latency;

  /// When true, every method throws after the simulated delay.
  final bool forceError;

  List<Disbursement>? _disbursements;

  Future<List<Disbursement>> _load() async {
    final cached = _disbursements;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_disbursementsAsset);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final disbursements =
        decoded
            .map((item) => Disbursement.fromJson(item as Map<String, dynamic>))
            .toList();
    return _disbursements = disbursements;
  }

  @override
  Future<List<Disbursement>> getDisbursementsByLocation(
    String locationId, {
    DisbursementStatus? status,
  }) async {
    await simulateMockCall(latency: latency, forceError: forceError);

    final entries =
        (await _load())
            .where((entry) => entry.locationId == locationId)
            .where((entry) => status == null || entry.status == status)
            .toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return List<Disbursement>.unmodifiable(entries);
  }

  @override
  Future<Disbursement> getDisbursementById(String id) async {
    await simulateMockCall(latency: latency, forceError: forceError);

    for (final entry in await _load()) {
      if (entry.id == id) return entry;
    }
    throw DisbursementNotFoundException(id);
  }

  @override
  Future<DisbursementSummary> getDisbursementSummary(String locationId) async {
    await simulateMockCall(latency: latency, forceError: forceError);

    final project = await MockProjectRepository().getProjectById(locationId);
    final collected = project?.raisedAmount ?? 0;
    final entries =
        (await _load())
            .where((entry) => entry.locationId == locationId)
            .toList();
    final disbursed =
        entries
            .where((entry) => entry.status == DisbursementStatus.disalurkan)
            .fold<int>(0, (sum, entry) => sum + entry.amount);
    final pending = (collected - disbursed).clamp(0, collected);

    return DisbursementSummary(
      collected: collected,
      disbursed: disbursed,
      pending: pending,
    );
  }
}
