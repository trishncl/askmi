const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, auth, FieldValue } = require("../lib/admin");
const { getCallerProfile, assertCanManageTarget } = require("../lib/permissions");
const { logActivity } = require("../lib/activity");
const { requireString, requireStatus } = require("../lib/validation");

const setUserAccountStatus = onCall(async (request) => {
  const caller = await getCallerProfile(request.auth);
  const data = request.data || {};

  const uid = requireString(data.uid, "User");
  const status = requireStatus(data.status);

  const targetRef = db.collection("users").doc(uid);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists) {
    throw new HttpsError("not-found", "The user account could not be found.");
  }
  const target = targetSnap.data();

  assertCanManageTarget(caller, { targetRole: target.role, targetBranch: target.branch });

  // The one rule that applies even to an Owner acting on themselves.
  if (uid === caller.uid && target.role === "Owner" && status !== "active") {
    throw new HttpsError(
      "failed-precondition",
      "Owners cannot deactivate their own account."
    );
  }

  // Disabling the Auth account is what actually blocks sign-in — the
  // Firestore `status` field alone only gates what the app's UI shows and
  // what Firestore rules allow; it doesn't stop someone from signing back
  // in with a valid password if the Auth record itself is left enabled.
  await auth.updateUser(uid, { disabled: status !== "active" });

  await targetRef.update({
    status,
    active: status === "active",
    updated_at: FieldValue.serverTimestamp(),
    updated_by: caller.uid,
  });

  await logActivity({
    action: status === "active" ? "Activated" : "Deactivated",
    targetUid: uid,
    targetName: target.name || target.email,
    administratorUid: caller.uid,
    administratorName: caller.name || caller.email,
    branch: target.branch,
  });

  return {};
});

module.exports = { setUserAccountStatus };