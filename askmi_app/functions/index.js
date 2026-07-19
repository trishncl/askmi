const { createUserAccount } = require("./callables/createUserAccount");
const { updateUserAccount } = require("./callables/updateUserAccount");
const { setUserAccountStatus } = require("./callables/setUserAccountStatus");
const { authorizePasswordReset } = require("./callables/authorizePasswordReset");
const { recordLogin } = require("./callables/recordLogin");

// Names must match exactly what the Flutter side calls via
// FirebaseFunctions.instance.httpsCallable('...') — see
// lib/services/user_admin_service.dart.
exports.createUserAccount = createUserAccount;
exports.updateUserAccount = updateUserAccount;
exports.setUserAccountStatus = setUserAccountStatus;
exports.authorizePasswordReset = authorizePasswordReset;
exports.recordLogin = recordLogin;