const { onCall } = require("firebase-functions/v2/https");
const { db, FieldValue } = require("../lib/admin");
const { getCallerProfile } = require("../lib/permissions");
const { logActivity } = require("../lib/activity");

/**
 * Called once by the client right after a successful sign-in (see
 * AuthService.signIn). Kept as its own tiny callable rather than a Auth
 * trigger (`beforeSignIn`/`onCreate`) because blocking/identity-platform
 * triggers need extra Identity Platform setup this project doesn't
 * otherwise need — a plain callable the client fires post-login is a lot
 * less infrastructure for the same "Last Login" + Activity Log entry.
 */
const recordLogin = onCall(async (request) => {
  const caller = await getCallerProfile(request.auth);

  await db.collection("users").doc(caller.uid).update({
    last_login_at: FieldValue.serverTimestamp(),
  });

  await logActivity({
    action: "Login",
    targetUid: caller.uid,
    targetName: caller.name || caller.email,
    administratorUid: caller.uid,
    administratorName: caller.name || caller.email,
    branch: caller.branch,
  });

  return {};
});

module.exports = { recordLogin };