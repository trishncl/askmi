const { HttpsError } = require("firebase-functions/v2/https");
const { db } = require("./admin");

/**
 * Loads the calling user's own profile doc — this is the ONLY source of
 * truth for "what role is this caller", never a client-supplied field.
 * Every callable in this backend calls this first.
 */
async function getCallerProfile(auth) {
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const snap = await db.collection("users").doc(auth.uid).get();
  if (!snap.exists) {
    throw new HttpsError(
      "permission-denied",
      "Your account has no profile on record."
    );
  }
  const profile = { uid: auth.uid, ...snap.data() };
  if (profile.status && profile.status !== "active") {
    throw new HttpsError(
      "permission-denied",
      "Your account is not active."
    );
  }
  return profile;
}

/**
 * Owner: full access, per the permissions brief.
 * Manager: may manage Staff/Manager accounts within their OWN branch only,
 * and can never touch (or create) an Owner account.
 * Anyone else: no access to manage other accounts.
 *
 * This throws rather than returning a bool so every callable fails the
 * same way (permission-denied) without repeating the error message.
 */
function assertCanManageTarget(caller, { targetRole, targetBranch }) {
  if (caller.role === "Owner") return;

  if (caller.role === "Manager") {
    if (targetRole === "Owner") {
      throw new HttpsError(
        "permission-denied",
        "Managers cannot manage Owner accounts."
      );
    }
    if (targetBranch !== caller.branch) {
      throw new HttpsError(
        "permission-denied",
        "Managers can only manage users in their own branch."
      );
    }
    return;
  }

  throw new HttpsError(
    "permission-denied",
    "You do not have permission to manage user accounts."
  );
}

module.exports = { getCallerProfile, assertCanManageTarget };