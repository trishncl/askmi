/// The ONE place branch names are defined. Every dropdown, filter, and
/// branch-locked Manager account reads from here.
///
/// These strings must match the `name` field of the documents in the
/// Firestore `branches` collection EXACTLY — every other collection stores
/// `branch` as a plain string, so a mismatch here silently returns zero
/// results rather than erroring.
const List<String> kBranchNames = [
  'Taal',
  'San Pascual',
  'Padre Garcia',
  'Balagtas',
];

/// Includes the "everything" option — valid for the Owner's dashboard
/// filter, but NOT for per-record dropdowns (a sale belongs to exactly one
/// real branch).
const String kAllBranches = 'All Branches';
const List<String> kBranchNamesWithAll = [kAllBranches, ...kBranchNames];