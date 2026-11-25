# 36 Error code

- Changed: `Error` carries an `Error_Code` instead of a message, and `ERROR_MESSAGES` in `errors.odin` holds one text per code.
- Works: the compiler rejects a code with no message, and `dump` prints the same text, so every golden is unchanged.
