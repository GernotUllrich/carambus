/**
 * Replaces all spaces in a string with '%20'
 * @param {string} str - The input string to encode
 * @returns {string} The encoded string with spaces replaced by '%20'
 */
export const encodeSpaces = (str) => {
  if (typeof str !== 'string') {
    return str;
  }
  return str.replace(/ /g, '%20');
};

// Example usage:
// const encoded = encodeSpaces('Hello World'); // Returns: 'Hello%20World' 