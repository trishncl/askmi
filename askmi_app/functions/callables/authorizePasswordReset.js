const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db } = require("../lib/admin");
const { getCallerProfile, assertCanManageTarget } = require("../lib/permissions");
const { logActivity } = require("../lib/activity");
const { requireString } = require("../lib/validation");

/**
 * Doesn't send anything itself — Firebase Auth's own
 * sendPasswordResetEmail (called client-side right after this resolves,
 * see UserAdminService.sendPasswordReset) already sends a signed,
 * time-limited reset link without needing a password to ever pass through
 * this backend. This callable's job is purely to (a) check the caller is
 * actually allowed to trigger a reset for this account, and (b) record
 * that they did, so it shows up in the Activity Log.
 */
const authorizePasswordReset = onCall(async (request) => {
  const caller = await getCallerProfile(request.auth);
  const data = request.data || {};
  const uid = requireString(data.uid, "User");

  const targetSnap = await db.collection("users").doc(uid).get();
  if (!targetSnap.exists) {
    throw new HttpsError("not-found", "The user account could not be found.");
  }
  const target = targetSnap.data();

  // Anyone may trigger their own reset; managing someone else's requires
  // the usual Owner/Manager-in-branch check.
  if (uid !== caller.uid) {
    assertCanManageTarget(caller, { targetRole: target.role, targetBranch: target.branch });
  }

  await logActivity({
    action: "Password reset",
    targetUid: uid,
    targetName: target.name || target.email,
    administratorUid: caller.uid,
    administratorName: caller.name || caller.email,
    branch: target.branch,
  });

  return {};
});

module.exports = { authorizePasswordReset };